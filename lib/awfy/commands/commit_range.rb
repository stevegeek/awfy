# frozen_string_literal: true

require "fileutils"

module Awfy
  module Commands
    class CommitRange < Base
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
        # Get the result store
        backend = options.storage_backend&.to_sym || :json
        result_store = ResultStoreFactory.create(options, backend)
        
        # Query all IPS results for this group/report
        query_params = {
          type: :ips,
          group: group[:name],
          report: report_name
        }
        
        results = result_store.query_results(query_params)
        
        if results.empty?
          say_error "No IPS benchmark results found for comparison"
          return
        end
        
        # Organize by commit and runtime
        results_by_commit = {}
        
        results.each do |result|
          # Extract metadata and result data
          metadata = result[:metadata]
          data = result[:data]
          
          commit = metadata["commit"]
          runtime = metadata["runtime"]
          
          # Skip if missing essential data
          next unless commit && runtime && data
          
          # Initialize commit entry if needed
          results_by_commit[commit] ||= {}
          results_by_commit[commit][:metadata] ||= {
            commit: commit,
            commit_message: metadata["commit_message"],
            ruby_version: metadata["ruby_version"],
            branch: metadata["branch"],
            timestamp: metadata["timestamp"]
          }
          
          # Add the result data for this runtime
          results_by_commit[commit][runtime.to_sym] = data
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
        # Get the result store
        backend = options.storage_backend&.to_sym || :json
        result_store = ResultStoreFactory.create(options, backend)
        
        # Query all memory results for this group/report
        query_params = {
          type: :memory,
          group: group[:name],
          report: report_name
        }
        
        results = result_store.query_results(query_params)
        
        if results.empty?
          say_error "No memory benchmark results found for comparison"
          return
        end
        
        # Organize by commit and runtime
        results_by_commit = {}
        
        results.each do |result|
          # Extract metadata and result data
          metadata = result[:metadata]
          data = result[:data]
          
          commit = metadata["commit"]
          runtime = metadata["runtime"]
          
          # Skip if missing essential data
          next unless commit && runtime && data
          
          # Initialize commit entry if needed
          results_by_commit[commit] ||= {}
          results_by_commit[commit][:metadata] ||= {
            commit: commit,
            commit_message: metadata["commit_message"],
            ruby_version: metadata["ruby_version"],
            branch: metadata["branch"],
            timestamp: metadata["timestamp"]
          }
          
          # Add the result data for this runtime
          results_by_commit[commit][runtime.to_sym] = data
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
        
        # Get the IPS view
        view = Views::ViewFactory.create(:ips, shell, options)
        
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
            
            view.test_performance_table(test_label, runtime, sorted_commits, results_by_commit)
          end
        end
        
        # Print a highlight table showing overall trends
        view.highlights_table(sorted_commits, results_by_commit)
      end
      
      def find_test_result(results_by_commit, commit, runtime, test_label)
        return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]
        
        results_by_commit[commit][runtime].find { |r| r["item"] == test_label }
      end
      
      def has_runtime?(results_by_commit, runtime)
        results_by_commit.any? { |_, data| data[runtime] }
      end
      
      def print_memory_performance_table(sorted_commits, results_by_commit)
        # Get tests from the first commit as reference
        first_commit = sorted_commits.first
        return if !first_commit || !results_by_commit[first_commit]
        
        # Get the Memory view
        view = Views::ViewFactory.create(:memory, shell, options)
        
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
            
            view.test_memory_table(test_label, runtime, sorted_commits, results_by_commit)
          end
        end
        
        # Print a highlight table showing overall trends
        view.memory_highlights_table(sorted_commits, results_by_commit)
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
end