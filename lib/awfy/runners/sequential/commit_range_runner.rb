# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # CommitRangeRunner runs benchmarks across a range of commits
      # Each commit is checked out and run in a fresh Ruby process for clean results
      class CommitRangeRunner < Awfy::Runners::Base
        # Run benchmarks across a range of commits
        # @param start_commit [String] The starting commit of the range
        # @param end_commit [String] The ending commit of the range (defaults to HEAD)
        # @param group [String, nil] Optional group name to run
        # @yield [Hash] Yields the combined results to the block
        # @return [Hash] Combined results from all commits
        def run(start_commit, end_commit = "HEAD", group = nil, &block)
          # Initialize the environment
          start!

          # Get list of commits in the range
          commit_list = get_commits_in_range(start_commit, end_commit)

          # Store results for each commit
          all_results = {}

          commit_list.each do |commit|
            results = run_on_commit(commit, group)

            # Add results to the combined results
            combine_results!(all_results, results)
          end

          # Call the block with the results if given
          if block_given?
            block.call(all_results)
          end

          all_results
        end

        private

        # Get the list of commits in the specified range
        # @param start_commit [String] The starting commit of the range
        # @param end_commit [String] The ending commit of the range
        # @return [Array<String>] List of commit hashes in the range
        def get_commits_in_range(start_commit, end_commit)
          # Resolve commit hashes first
          start_hash = git_client.rev_parse(start_commit)
          end_hash = git_client.rev_parse(end_commit)

          # Get all commits in the range (inclusive of start and end)
          commit_range = "#{start_hash}^..#{end_hash}"
          commits = git_client.rev_list("--reverse", commit_range)

          # If start commit wasn't included due to the ^ operator, add it back
          start_index = commits.index(start_hash)
          if start_index.nil?
            commits.unshift(start_hash)
          end

          commits
        end

        # Run benchmarks on a specific commit
        # @param commit [String] The commit hash to run on
        # @param group [String, nil] Optional group name to run
        # @param report_name [String, nil] Optional report name to run
        # @param test_name [String, nil] Optional test name to run
        # @param command_type [String] The command type (ips, memory, etc.)
        # @return [Hash] Results from the run
        def run_on_commit(commit, group = nil, report_name = nil, test_name = nil, command_type = nil)
          results = nil
          commit_message = nil

          # Checkout the commit and run benchmarks in a fresh process
          safe_checkout(commit) do
            # Get commit metadata
            commit_message = git_client.commit_message(commit)

            if config.verbose?
              say "Running benchmarks on commit: #{commit.slice(0, 8)} - #{commit_message}"
            end

            # Run the benchmark command in a fresh process
            cmd_type = command_type || "ips"
            run_in_fresh_process(cmd_type, group, report_name, test_name)

            # Load the results
            results = load_results(commit, commit_message)
          end

          results
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
