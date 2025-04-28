# frozen_string_literal: true

require "fileutils"

module Awfy
  class CommitRange < Command
    def initialize(runner, shell, git_client, options)
      super(runner, shell, git_client, options)
      FileUtils.mkdir_p(options.results_directory)
    end

    def benchmark(benchmark_type, group, report_name, test_name)
      # Save current branch before starting
      current_branch = git_current_branch_name
      say "Current branch: #{current_branch}" if verbose?

      begin
        # Get commits to benchmark
        if options.results_only
          # Just display results without running benchmarks
          say "Displaying results only (no benchmarks will be run)" if verbose?
          summarize_results(benchmark_type, group, report_name)
          return
        end
        
        start_commit, end_commit = parse_commit_range
        
        # Display commit range information
        start_desc = get_commit_message(start_commit)
        end_desc = get_commit_message(end_commit)
        say "Commit range: #{start_commit[0..7]} (#{start_desc}) .. #{end_commit[0..7]} (#{end_desc})" if verbose?
        
        commits = get_commits_in_range(start_commit, end_commit)
        
        # Filter ignored commits
        ignored_commits = parse_ignore_pattern(options.ignore_commits)
        filtered_commits = filter_ignored_commits(commits, ignored_commits)
        
        if ignored_commits.any?
          ignored_count = commits.size - filtered_commits.size
          say "Ignoring #{ignored_count} commits" if verbose? && ignored_count > 0
        end
        
        say "Found #{filtered_commits.length} commits to benchmark" if verbose?
        
        # Process each commit
        filtered_commits.each_with_index do |commit, index|
          say "\n==== Benchmarking commit #{index + 1}/#{filtered_commits.length}: #{commit} ====" if verbose?
          
          commit_msg = get_commit_message(commit)
          say "#{commit[0..7]}: #{commit_msg}" if verbose?
          
          # Check for cached results if use_cached is enabled
          if options.use_cached && has_cached_results?(commit, benchmark_type)
            say "Using cached benchmark results for commit #{commit[0..7]}" if verbose?
            next
          end
          
          # Run benchmark on this commit by launching a new process
          safe_checkout(commit) do
            run_benchmark_in_new_process(benchmark_type, group[:name], report_name, test_name, commit)
          end
        end
        
        # Summarize results across all commits
        say "\n==== Completed benchmarking #{filtered_commits.length} commits ====" if verbose?
        summarize_results(benchmark_type, group, report_name)
        
      ensure
        # Return to original branch
        say "Returning to original branch #{current_branch}" if verbose?
        git_client.checkout(current_branch)
      end
    end
    
    private
    
    def parse_commit_range
      range = options.commit_range
      if !range || range.empty?
        say_error "No commit range specified"
        exit(1)
      end
      
      start_commit, end_commit = range.split("..")
      if !start_commit || !end_commit
        say_error "Invalid commit range format. Expected: 'start_commit..end_commit'"
        say_error "Example: 'compare ips HEAD~5..HEAD group_name'"
        say_error "To ignore commits: --ignore-commits=abc123,def456..ghi789"
        exit(1)
      end
      
      [start_commit, end_commit]
    end
    
    def get_commits_in_range(start_commit, end_commit)
      # Resolve full commit hashes
      begin
        start_hash = git_client.lib.command("rev-parse", start_commit).strip
      rescue => e
        say_error "Invalid start commit: #{start_commit}"
        say_error "Error: #{e.message}"
        exit(1)
      end
      
      begin
        end_hash = git_client.lib.command("rev-parse", end_commit).strip
      rescue => e
        say_error "Invalid end commit: #{end_commit}"
        say_error "Error: #{e.message}"
        exit(1)
      end
      
      # Get all commits between start and end in chronological order
      begin
        commits = git_client.lib.command("rev-list", "--reverse", "#{start_hash}^..#{end_hash}").split("\n")
      rescue => e
        say_error "Error determining commits in range: #{start_commit}..#{end_commit}"
        say_error "Error: #{e.message}"
        exit(1)
      end
      
      # If no commits found, the range might be reversed or invalid
      if commits.empty?
        say_error "No commits found in range: #{start_commit}..#{end_commit}"
        say_error "Check that your start commit is older than your end commit"
        exit(1)
      end
      
      # Ensure start commit is included (in case start is a merge base)
      if !commits.include?(start_hash)
        commits.unshift(start_hash)
      end
      
      commits
    end
    
    def parse_ignore_pattern(ignore_string)
      return [] unless ignore_string
      
      ignored = []
      patterns = ignore_string.split(",")
      
      patterns.each do |pattern|
        if pattern.include?("..")
          # Handle range format: hash1..hash2
          start_hash, end_hash = pattern.split("..")
          # Get all commits in this range and add to ignored list
          begin
            range_commits = get_commits_in_range(start_hash, end_hash)
            ignored.concat(range_commits)
          rescue => e
            say_error "Could not process ignore range: #{pattern}"
            say_error "Error: #{e.message}" if verbose?
          end
        else
          # Single commit hash - resolve to full hash
          begin
            full_hash = git_client.lib.command("rev-parse", pattern).strip
            ignored << full_hash
          rescue => e
            say_error "Could not resolve commit hash: #{pattern}"
            say_error "Error: #{e.message}" if verbose?
          end
        end
      end
      
      ignored.uniq
    end
    
    def filter_ignored_commits(commits, ignored_commits)
      commits.reject { |commit| ignored_commits.include?(commit) }
    end
    
    def get_commit_message(commit)
      begin
        git_client.lib.command("log", "--format=%s", "-n", "1", commit).strip
      rescue => e
        # Return a placeholder if we can't get the message
        "unknown commit message"
      end
    end
    
    def safe_checkout(commit, &block)
      # Save the current state
      git_client.lib.stash_save("awfy auto stash")
      
      begin
        # Checkout the commit
        say "Checking out commit #{commit[0..7]}" if verbose?
        git_client.checkout(commit)
        
        # Wait for filesystem to settle
        sleep 1
        
        # Run the block with the commit checked out
        yield
      ensure
        # Pop any stashed changes (ignore errors if nothing was stashed)
        begin
          git_client.lib.command("stash", "pop")
        rescue
          # Ignore stash pop errors
        end
      end
    end
    
    def has_cached_results?(commit, benchmark_type)
      # Check if we have results for this commit already
      matches = []
      
      runtime = options.runtime
      if runtime == "both" || runtime == "mri"
        mri_file = "#{options.results_directory}/*-#{benchmark_type}-mri-*-#{commit[0..7]}*.json"
        matches += Dir.glob(mri_file)
      end
      
      if runtime == "both" || runtime == "yjit"
        yjit_file = "#{options.results_directory}/*-#{benchmark_type}-yjit-*-#{commit[0..7]}*.json"
        matches += Dir.glob(yjit_file)
      end
      
      !matches.empty?
    end
    
    def run_benchmark_in_new_process(benchmark_type, group_name, report_name, test_name, commit)
      # Construct the command to run the benchmark in a separate process
      cmd = ["ruby", "-r", "./lib/awfy", "exe/awfy", benchmark_type]
      
      # Add group, report, test if provided
      cmd << group_name if group_name
      cmd << report_name if report_name
      cmd << test_name if test_name
      
      # Add options
      cmd << "--save"  # Always save results for commit comparisons
      cmd << "--verbose" if options.verbose?
      cmd << "--quiet" if options.quiet?
      cmd << "--runtime=#{options.runtime}"
      cmd << "--summary=#{options.summary}"
      cmd << "--summary-order=#{options.summary_order}"
      
      # Add benchmark specific options
      cmd << "--ips-warmup=#{options.test_warm_up}" if benchmark_type == "ips"
      cmd << "--ips-time=#{options.test_time}" if benchmark_type == "ips"
      cmd << "--test-iterations=#{options.test_iterations}"
      
      # Add metadata to identify this run for a specific commit
      # We'll append this as a file naming convention
      meta_filename = "commit=#{commit[0..7]}"
      
      # Run the command
      runtime_label = options.runtime == "both" ? "MRI and YJIT" : options.runtime.upcase
      say "Running #{benchmark_type} benchmarks with #{runtime_label} for commit #{commit[0..7]}" if verbose?
      
      # Run a different command for each runtime if "both" is specified
      if options.runtime == "both"
        # Run MRI
        mri_cmd = cmd.dup
        mri_cmd << "--runtime=mri"
        system(*mri_cmd)
        
        # Run YJIT
        yjit_cmd = cmd.dup
        yjit_cmd << "--runtime=yjit"
        system(*yjit_cmd)
      else
        system(*cmd)
      end
    end
    
    def summarize_results(benchmark_type, group, report_name)
      say "\n==== BENCHMARK SUMMARY ACROSS COMMITS ====" if verbose?
      
      # Processing will be different for each benchmark type
      case benchmark_type
      when "ips"
        summarize_ips_results(group, report_name)
      when "memory"
        summarize_memory_results(group, report_name)
      when "profile"
        say "Summary not available for profile benchmark type across commits"
      end
    end
    
    def summarize_ips_results(group, report_name)
      # Load all awfy metadata files for this group/report
      awfy_files = if report_name
        Dir.glob("#{options.results_directory}/*-awfy-ips-#{group[:name]}-#{report_name}.json")
      else
        Dir.glob("#{options.results_directory}/*-awfy-ips-#{group[:name]}*.json")
      end
      
      if awfy_files.empty?
        say_error "No IPS benchmark results found for comparison"
        return
      end
      
      # Load metadata from awfy files
      metadata_entries = []
      awfy_files.each do |file|
        begin
          data = JSON.parse(File.read(file))
          metadata_entries.concat(data)
        rescue => e
          say_error "Error reading awfy metadata file #{file}: #{e.message}"
        end
      end
      
      # Organize by commit and runtime
      results_by_commit = {}
      metadata_entries.each do |entry|
        commit = entry["commit"]
        runtime = entry["runtime"]
        
        # Load actual benchmark results
        if File.exist?(entry["output_path"])
          results = JSON.parse(File.read(entry["output_path"]))
          
          results_by_commit[commit] ||= {}
          results_by_commit[commit][:metadata] ||= {
            commit: commit,
            commit_message: entry["commit_message"],
            ruby_version: entry["ruby_version"],
            branch: entry["branch"],
            timestamp: entry["timestamp"]
          }
          
          results_by_commit[commit][runtime.to_sym] = results
        end
      end
      
      # Get commit timestamps for proper ordering
      commit_timestamps = {}
      results_by_commit.keys.each do |commit|
        # Use the timestamp from metadata or get from git
        timestamp = results_by_commit[commit][:metadata][:timestamp]
        commit_timestamps[commit] = timestamp.to_i
      end
      
      # Sort results by commit timestamp (chronological order)
      sorted_commits = results_by_commit.keys.sort_by { |commit| commit_timestamps[commit] }
      
      # Print performance tables
      print_ips_performance_table(sorted_commits, results_by_commit)
    end
    
    def summarize_memory_results(group, report_name)
      # Load all awfy metadata files for this group/report
      awfy_files = if report_name
        Dir.glob("#{options.results_directory}/*-awfy-memory-#{group[:name]}-#{report_name}.json")
      else
        Dir.glob("#{options.results_directory}/*-awfy-memory-#{group[:name]}*.json")
      end
      
      if awfy_files.empty?
        say_error "No memory benchmark results found for comparison"
        return
      end
      
      # Load metadata from awfy files
      metadata_entries = []
      awfy_files.each do |file|
        begin
          data = JSON.parse(File.read(file))
          metadata_entries.concat(data)
        rescue => e
          say_error "Error reading awfy metadata file #{file}: #{e.message}"
        end
      end
      
      # Organize by commit and runtime
      results_by_commit = {}
      metadata_entries.each do |entry|
        commit = entry["commit"]
        runtime = entry["runtime"]
        
        # Load actual benchmark results
        if File.exist?(entry["output_path"])
          results = JSON.parse(File.read(entry["output_path"]))
          
          results_by_commit[commit] ||= {}
          results_by_commit[commit][:metadata] ||= {
            commit: commit,
            commit_message: entry["commit_message"],
            ruby_version: entry["ruby_version"],
            branch: entry["branch"],
            timestamp: entry["timestamp"]
          }
          
          results_by_commit[commit][runtime.to_sym] = results
        end
      end
      
      # Get commit timestamps for proper ordering
      commit_timestamps = {}
      results_by_commit.keys.each do |commit|
        # Use the timestamp from metadata or get from git
        timestamp = results_by_commit[commit][:metadata][:timestamp]
        commit_timestamps[commit] = timestamp.to_i
      end
      
      # Sort results by commit timestamp (chronological order)
      sorted_commits = results_by_commit.keys.sort_by { |commit| commit_timestamps[commit] }
      
      # Print performance tables
      print_memory_performance_table(sorted_commits, results_by_commit)
    end
    
    
    def print_ips_performance_table(sorted_commits, results_by_commit)
      # Get tests from the first commit as reference
      first_commit = sorted_commits.first
      return if !first_commit || !results_by_commit[first_commit]
      
      runtime_keys = [:mri, :yjit].select { |key| results_by_commit[first_commit][key] }
      
      runtime_keys.each do |runtime|
        say "\n=== Performance with #{runtime.to_s.upcase} ==="
        
        # Get test labels from the first commit
        reference_results = results_by_commit[first_commit][runtime]
        return unless reference_results
        
        # For each test in the reference, create a performance table
        reference_results.each do |test_result|
          test_label = test_result["item"]
          # Skip if not a real test (e.g. comparison headers)
          next unless test_label
          
          print_test_performance(sorted_commits, results_by_commit, runtime, test_label)
        end
      end
      
      # Print a highlight table showing overall trends
      print_highlights_table(sorted_commits, results_by_commit)
    end
    
    def print_test_performance(sorted_commits, results_by_commit, runtime, test_label)
      # Get baseline IPS (first commit for this test)
      first_commit = sorted_commits.first
      baseline_result = find_test_result(results_by_commit, first_commit, runtime, test_label)
      baseline_ips = baseline_result ? baseline_result["ips"] : nil
      
      rows = []
      
      sorted_commits.each do |commit|
        # Get commit metadata
        metadata = results_by_commit[commit][:metadata]
        commit_short = commit[0..7]
        commit_msg = metadata[:commit_message].to_s[0..27] + "..."
        
        # Find this test in the results
        result = find_test_result(results_by_commit, commit, runtime, test_label)
        
        if result
          ips = result["ips"]
          
          comparison = if baseline_ips && ips && commit != first_commit
            comparison_value = (ips / baseline_ips).round(2)
            if comparison_value > 1.0
              "#{comparison_value}x faster"
            elsif comparison_value < 1.0
              "#{(1.0 / comparison_value).round(2)}x slower"
            else
              "same"
            end
          else
            "baseline"
          end
          
          rows << [commit_short, commit_msg, humanize_scale(ips), comparison]
        else
          rows << [commit_short, commit_msg, "N/A", "N/A"]
        end
      end
      
      # Use the base Command's table output method
      table_title = "#{test_label} (#{runtime.to_s.upcase}, iterations per second)"
      output_summary_table([{group: "Commits", report: "IPS Comparison"}], rows, "Commit", "Description", "IPS", "vs Baseline")
    end
    
    def find_test_result(results_by_commit, commit, runtime, test_label)
      return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]
      
      results_by_commit[commit][runtime].find { |r| r["item"] == test_label }
    end
    
    def print_highlights_table(sorted_commits, results_by_commit)
      # Define headings based on available runtimes
      headings = ["Commit", "Description"]
      
      # Add runtime fields if we have them
      if has_runtime?(results_by_commit, :mri)
        headings << "MRI IPS Change"
      end
      
      if has_runtime?(results_by_commit, :yjit)
        headings << "YJIT IPS Change"
      end
      
      if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
        headings << "YJIT vs MRI"
      end
      
      # Get baseline data
      baseline_commit = sorted_commits.first
      baseline_mri_ips = get_first_test_ips(results_by_commit, baseline_commit, :mri)
      baseline_yjit_ips = get_first_test_ips(results_by_commit, baseline_commit, :yjit)
      
      rows = []
      
      # Show baseline row
      baseline_row = [
        baseline_commit[0..7],
        results_by_commit[baseline_commit][:metadata][:commit_message].to_s[0..22] + "..."
      ]
      
      if has_runtime?(results_by_commit, :mri)
        baseline_row << "baseline"
      end
      
      if has_runtime?(results_by_commit, :yjit)
        baseline_row << "baseline"
      end
      
      if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
        if baseline_mri_ips && baseline_yjit_ips
          baseline_row << "#{(baseline_yjit_ips / baseline_mri_ips).round(2)}x"
        else
          baseline_row << "N/A"
        end
      end
      
      rows << baseline_row
      
      # Skip the first one (baseline)
      sorted_commits[1..].each do |commit|
        metadata = results_by_commit[commit][:metadata]
        commit_short = commit[0..7]
        commit_msg = metadata[:commit_message].to_s[0..22] + "..."
        
        row = [commit_short, commit_msg]
        
        # MRI IPS change
        if has_runtime?(results_by_commit, :mri)
          current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)
          
          if current_mri_ips && baseline_mri_ips
            ips_ratio = (current_mri_ips / baseline_mri_ips).round(2)
            mri_change = format_change(ips_ratio)
            row << mri_change
          else
            row << "N/A"
          end
        end
        
        # YJIT IPS change
        if has_runtime?(results_by_commit, :yjit)
          current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)
          
          if current_yjit_ips && baseline_yjit_ips
            ips_ratio = (current_yjit_ips / baseline_yjit_ips).round(2)
            yjit_change = format_change(ips_ratio)
            row << yjit_change
          else
            row << "N/A"
          end
        end
        
        # YJIT vs MRI for this commit
        if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
          current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)
          current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)
          
          if current_mri_ips && current_yjit_ips
            ratio = (current_yjit_ips / current_mri_ips).round(2)
            row << "#{ratio}x"
          else
            row << "N/A"
          end
        end
        
        rows << row
      end
      
      # Create and display the table
      output_summary_table([{group: "Highlights", report: "Performance across commits"}], rows, *headings)
    end
    
    def has_runtime?(results_by_commit, runtime)
      results_by_commit.any? { |_, data| data[runtime] }
    end
    
    def get_first_test_ips(results_by_commit, commit, runtime)
      return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]
      
      # Get the first real test result
      first_test = results_by_commit[commit][runtime].find { |r| r["item"] }
      first_test ? first_test["ips"] : nil
    end
    
    def format_change(ratio)
      if ratio > 1.0
        "+#{((ratio - 1) * 100).round(1)}%"
      elsif ratio < 1.0
        "-#{((1 - ratio) * 100).round(1)}%"
      else
        "No change"
      end
    end
    
    def print_memory_performance_table(sorted_commits, results_by_commit)
      # Get tests from the first commit as reference
      first_commit = sorted_commits.first
      return if !first_commit || !results_by_commit[first_commit]
      
      runtime_keys = [:mri, :yjit].select { |key| results_by_commit[first_commit][key] }
      
      runtime_keys.each do |runtime|
        say "\n=== Memory Usage with #{runtime.to_s.upcase} ==="
        
        # Get test labels from the first commit
        reference_results = results_by_commit[first_commit][runtime]
        return unless reference_results
        
        # For each test in the reference, create a memory table
        reference_results.each do |test_result|
          test_label = test_result["item"]
          # Skip if not a real test (e.g. comparison headers)
          next unless test_label
          
          print_test_memory_usage(sorted_commits, results_by_commit, runtime, test_label)
        end
      end
      
      # Print a highlight table showing overall trends
      print_memory_highlights_table(sorted_commits, results_by_commit)
    end
    
    def print_test_memory_usage(sorted_commits, results_by_commit, runtime, test_label)
      # Get baseline memory (first commit for this test)
      first_commit = sorted_commits.first
      baseline_result = find_test_result(results_by_commit, first_commit, runtime, test_label)
      baseline_memory = baseline_result && baseline_result["memory"] ? baseline_result["memory"]["memsize"] : nil
      
      rows = []
      
      sorted_commits.each do |commit|
        # Get commit metadata
        metadata = results_by_commit[commit][:metadata]
        commit_short = commit[0..7]
        commit_msg = metadata[:commit_message].to_s[0..27] + "..."
        
        # Find this test in the results
        result = find_test_result(results_by_commit, commit, runtime, test_label)
        
        if result && result["memory"]
          bytes = result["memory"]["memsize"]
          objects = result["memory"]["objects"]
          
          comparison = if baseline_memory && bytes && commit != first_commit
            comparison_value = (bytes.to_f / baseline_memory).round(2)
            if comparison_value < 1.0
              "#{((1 - comparison_value) * 100).round(1)}% better"
            elsif comparison_value > 1.0
              "#{((comparison_value - 1) * 100).round(1)}% worse"
            else
              "same"
            end
          else
            "baseline"
          end
          
          rows << [commit_short, commit_msg, humanize_scale(bytes), humanize_scale(objects), comparison]
        else
          rows << [commit_short, commit_msg, "N/A", "N/A", "N/A"]
        end
      end
      
      # Use the base Command's table output method
      table_title = "#{test_label} (#{runtime.to_s.upcase}, memory usage)"
      output_summary_table([{group: "Commits", report: "Memory Comparison"}], rows, 
                         "Commit", "Description", "Bytes", "Objects", "vs Baseline")
    end
    
    def print_memory_highlights_table(sorted_commits, results_by_commit)
      headings = ["Commit", "Description", "Memory Change", "Objects Change"]
      
      # Get baseline data
      baseline_commit = sorted_commits.first
      
      # Use MRI results for memory comparisons
      runtime = has_runtime?(results_by_commit, :mri) ? :mri : :yjit
      baseline_result = find_first_test_with_memory(results_by_commit, baseline_commit, runtime)
      
      if !baseline_result
        say "No baseline memory data available for comparison"
        return
      end
      
      baseline_memory = baseline_result["memory"]["memsize"]
      baseline_objects = baseline_result["memory"]["objects"]
      
      rows = []
      
      # Show baseline row
      baseline_row = [
        baseline_commit[0..7],
        results_by_commit[baseline_commit][:metadata][:commit_message].to_s[0..22] + "...",
        "baseline",
        "baseline"
      ]
      
      rows << baseline_row
      
      # Skip the first one (baseline)
      sorted_commits[1..].each do |commit|
        metadata = results_by_commit[commit][:metadata]
        commit_short = commit[0..7]
        commit_msg = metadata[:commit_message].to_s[0..22] + "..."
        
        current_result = find_first_test_with_memory(results_by_commit, commit, runtime)
        
        if current_result && current_result["memory"]
          current_memory = current_result["memory"]["memsize"]
          current_objects = current_result["memory"]["objects"]
          
          # Memory change
          memory_comparison = if current_memory && baseline_memory
            (current_memory.to_f / baseline_memory).round(2)
          else
            nil
          end
          
          memory_change = if memory_comparison
            if memory_comparison < 1.0
              "-#{((1 - memory_comparison) * 100).round(1)}%"
            elsif memory_comparison > 1.0
              "+#{((memory_comparison - 1) * 100).round(1)}%"
            else
              "No change"
            end
          else
            "N/A"
          end
          
          # Objects change
          objects_comparison = if current_objects && baseline_objects
            (current_objects.to_f / baseline_objects).round(2)
          else
            nil
          end
          
          objects_change = if objects_comparison
            if objects_comparison < 1.0
              "-#{((1 - objects_comparison) * 100).round(1)}%"
            elsif objects_comparison > 1.0
              "+#{((objects_comparison - 1) * 100).round(1)}%"
            else
              "No change"
            end
          else
            "N/A"
          end
          
          rows << [commit_short, commit_msg, memory_change, objects_change]
        else
          rows << [commit_short, commit_msg, "N/A", "N/A"]
        end
      end
      
      # Create and display the table
      output_summary_table([{group: "Memory Highlights", report: "Across commits"}], rows, *headings)
    end
    
    def find_first_test_with_memory(results_by_commit, commit, runtime)
      return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]
      
      # Find the first test that has memory data
      results_by_commit[commit][runtime].find do |result|
        result["item"] && result["memory"]
      end
    end
  end
end