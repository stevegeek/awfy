# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # CommitRangeRunner runs benchmarks across a range of commits
      # Each commit is checked out and run in a fresh Ruby process for clean results
      class CommitRangeRunner < Awfy::Runners::Base
        # Run a specific group across all commits
        # @param group [Awfy::Suites::Group] The group to run
        # @yield [Awfy::Suites::Group] Yields the group to create a job
        def run_group(group, &block)
          # Initialize the environment
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          # Parse commit range from config
          start_commit, end_commit = parse_commit_range(config.commit_range)

          # Get list of commits in the range
          commit_list = get_commits_in_range(start_commit, end_commit)

          # Set control commit to first commit in range if not specified
          if config.control_commit.nil? || config.control_commit.empty?
            @control_commit = commit_list.first
            if config.verbose? VerbosityLevel::BASIC
              say "Using first commit as control: #{@control_commit.slice(0, 8)}"
            end
          else
            # Resolve the provided control commit to a full hash
            @control_commit = git_client.rev_parse(config.control_commit)
            if config.verbose? VerbosityLevel::BASIC
              say "Using specified commit as control: #{@control_commit.slice(0, 8)}"
            end
          end

          # Run the group on each commit
          commit_list.each do |commit|
            run_group_on_commit(commit, group, &block)
          end
        end

        private

        # Safely checkout a git reference, run a block, and return to the original state
        # @param ref [String] The git reference (branch, commit, etc.) to checkout
        # @yield Execute the given block with the reference checked out
        def safe_checkout(ref, &block)
          git_client.stashed_checkout(ref, &block)
        end

        # Run a command in a fresh Ruby process
        # @param command_type [String] The command type (ips, memory, etc.)
        # @param group_name [String, nil] Optional group name to run
        # @param report_name [String, nil] Optional report name to run
        # @param test_name [String, nil] Optional test name to run
        # @return [Boolean] Whether the command succeeded
        def run_in_fresh_process(command_type, group_name = nil, report_name = nil, test_name = nil)
          # Build the command to run the benchmark in a separate process
          cmd = ["bundle", "exec", "awfy", command_type.to_s, "start"]

          # Add group, report, test if provided
          cmd << group_name if group_name
          cmd << report_name if report_name
          cmd << test_name if test_name

          # Add configuration options
          cmd << "--runtime=#{config.runtime}" if config.runtime
          cmd << "--test-time=#{config.test_time}" if config.test_time
          cmd << "--test-warm-up=#{config.test_warm_up}" if config.test_warm_up
          cmd << "--storage-backend=#{config.storage_backend}" if config.storage_backend
          cmd << "--storage-name=#{config.storage_name}" if config.storage_name
          cmd << "--setup-file-path=#{config.setup_file_path}" if config.setup_file_path
          cmd << "--tests-path=#{config.tests_path}" if config.tests_path
          cmd << "--target-repo-path=#{config.target_repo_path}" if config.target_repo_path
          cmd << "--control-commit=#{@control_commit}" if @control_commit
          cmd << "--verbose=#{config.verbose.value}" if config.verbose && config.verbose.value > 0

          # Execute the command
          if config.verbose? VerbosityLevel::DEBUG
            say "Executing: #{cmd.join(" ")}"
          end

          # Capture and display output from spawned process
          require "open3"
          stdout, stderr, status = Open3.capture3(*cmd)

          # Display the output from the spawned process
          puts stdout unless stdout.empty?
          puts stderr unless stderr.empty?

          unless status.success?
            say_error "Benchmark command failed in spawned process"
            raise "Benchmark command failed in spawned process (exit code: #{status.exitstatus})"
          end

          true
        end

        # Parse commit range string into start and end commits
        # @param range_str [String] Commit range string (e.g., "main..HEAD" or "abc123..def456")
        # @return [Array<String>] Array with [start_commit, end_commit]
        def parse_commit_range(range_str)
          raise ArgumentError, "commit_range option is required for commit_range runner" if range_str.nil? || range_str.empty?

          # Split on .. or ...
          parts = range_str.split(/\.{2,3}/)

          if parts.length == 1
            # Single commit provided, use it as both start and end
            [parts[0], parts[0]]
          elsif parts.length == 2
            # Range provided
            start_commit = parts[0].empty? ? "HEAD" : parts[0]
            end_commit = parts[1].empty? ? "HEAD" : parts[1]
            [start_commit, end_commit]
          else
            raise ArgumentError, "Invalid commit range format: #{range_str}"
          end
        end

        # Get the list of commits in the specified range
        # @param start_commit [String] The starting commit of the range
        # @param end_commit [String] The ending commit of the range
        # @return [Array<String>] List of commit hashes in the range
        def get_commits_in_range(start_commit, end_commit)
          # Resolve commit hashes first
          start_hash = git_client.rev_parse(start_commit)
          end_hash = git_client.rev_parse(end_commit)

          # If start and end are the same, return just that commit
          if start_hash == end_hash
            return [start_hash]
          end

          # Check if start_hash is a root commit (has no parent)
          is_root_commit = begin
            git_client.rev_parse("#{start_hash}^")
            false
          rescue
            true
          end

          # Get all commits in the range (inclusive of start and end)
          if is_root_commit
            # For root commits, we can't use ^, so just use the range directly
            # and manually include the start commit
            commit_range = "#{start_hash}..#{end_hash}"
            commits = git_client.rev_list("--reverse", commit_range)
            commits.unshift(start_hash)
          else
            # For non-root commits, use ^ to include the start commit
            commit_range = "#{start_hash}^..#{end_hash}"
            commits = git_client.rev_list("--reverse", commit_range)

            # If start commit wasn't included due to the ^ operator, add it back
            start_index = commits.index(start_hash)
            if start_index.nil?
              commits.unshift(start_hash)
            end
          end

          commits
        end

        # Run a specific group on a specific commit
        # @param commit [String] The commit hash to run on
        # @param group [Awfy::Suites::Group] The group to run
        # @yield [Awfy::Suites::Group] Yields the group to create a job
        def run_group_on_commit(commit, group, &block)
          # Checkout the commit and run benchmarks
          safe_checkout(commit) do
            # Get commit metadata
            commit_message = git_client.commit_message(commit)

            if config.verbose?
              say "Running benchmarks on commit: #{commit.slice(0, 8)} - #{commit_message}"
            end

            # Get the job instance to determine the command type
            job = yield group

            # Determine the command type from the job class (e.g., "IPS" -> "ips", "Memory" -> "memory")
            command_type = job.class.name.split("::").last.downcase

            # Run in a fresh process to ensure code is reloaded from the checked-out commit
            # This is critical - without it, Ruby will cache the previously loaded code
            run_in_fresh_process(command_type, group.name)
          end
        end

        # Load results from the most recent run
        # @param commit [String] The commit hash the results are for
        # @param commit_message [String] The commit message for the commit
        # @return [Hash] The loaded results
        def load_results(commit, commit_message)
          # Find the most recent result file
          results_directory = "#{session.config.storage_name}/benchmark_results"
          result_files = Dir.glob(File.join(results_directory, "*.json"))
          latest_file = result_files.max_by { |f| File.mtime(f) }

          return {} unless latest_file

          # Load the results and tag with commit info
          results = JSON.parse(File.read(latest_file))

          # Add commit information to each result
          tagged_results = {}
          results.each do |group, values|
            tagged_results[group] = values.map do |result|
              result_with_commit = result.dup
              result_with_commit["commit"] = commit
              result_with_commit["commit_message"] = commit_message
              result_with_commit
            end
          end

          tagged_results
        end

        # Combine results from multiple commits into a single structure
        # @param all_results [Hash] The combined results (modified in place)
        # @param commit_results [Hash] Results from a single commit
        # @return [Hash] The combined results
        def combine_results!(all_results, commit_results)
          # Add the new results to the combined results
          commit_results.each do |group, results|
            if all_results.key?(group)
              all_results[group].concat(results)
            else
              all_results[group] = results
            end
          end

          all_results
        end
      end
    end
  end
end
