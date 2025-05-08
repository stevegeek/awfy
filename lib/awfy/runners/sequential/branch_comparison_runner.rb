# frozen_string_literal: true

module Awfy
  module Runners
    # BranchComparisonRunner runs benchmarks to compare performance between git branches
    # Each branch is run in a fresh Ruby process to ensure clean environment
    class BranchComparisonRunner < Base
      # Run benchmarks comparing performance across branches
      # @param main_branch [String] The main branch to compare against
      # @param comparison_branch [String] The branch to compare with
      # @param group [String, nil] Optional group name to run
      # @yield [Group] Yields the group being run to the block
      # @return [void]
      def run(main_branch, comparison_branch, group = nil, &block)
        # Initialize the environment
        start!

        # Store results for each branch
        main_results = run_on_branch(main_branch, group)
        comparison_results = run_on_branch(comparison_branch, group)

        # Process and combine results
        all_results = combine_results(main_results, comparison_results)

        if block_given?
          block.call(all_results)
        end

        all_results
      end

      private

      # Run benchmarks on a specific branch
      # @param branch [String] The branch to run on
      # @param group [String, nil] Optional group name to run
      # @param report_name [String, nil] Optional report name to run
      # @param test_name [String, nil] Optional test name to run
      # @param command_type [String] The command type (ips, memory, etc.)
      # @return [Hash] Results from the run
      def run_on_branch(branch, group = nil, report_name = nil, test_name = nil, command_type = nil)
        results = nil

        # Checkout the branch and run benchmarks in a fresh process
        safe_checkout(branch) do
          shell.say "Running benchmarks on branch: #{branch}" if options.verbose?

          # Run the benchmark command in a fresh process
          cmd_type = command_type || options.command || "ips"
          run_in_fresh_process(cmd_type, group, report_name, test_name)

          # Load the results
          results = load_results(branch)
        end

        results
      end

      # Load results from the most recent run
      # @param branch [String] The branch the results are for
      # @return [Hash] The loaded results
      def load_results(branch)
        # Find the most recent result file
        result_files = Dir.glob(File.join(options.results_directory, "*.json"))
        latest_file = result_files.max_by { |f| File.mtime(f) }

        return {} unless latest_file

        # Load the results and tag with branch info
        results = JSON.parse(File.read(latest_file))

        # Add branch information to each result
        tagged_results = {}
        results.each do |group, values|
          tagged_results[group] = values.map do |result|
            result_with_branch = result.dup
            result_with_branch["branch"] = branch
            result_with_branch
          end
        end
        tagged_results
      end

      # Combine results from multiple branches
      # @param main_results [Hash] Results from the main branch
      # @param comparison_results [Hash] Results from the comparison branch
      # @return [Hash] Combined results
      def combine_results(main_results, comparison_results)
        # Start with main results
        combined = deep_copy(main_results)

        # Add comparison results
        comparison_results.each do |group, results|
          if combined.key?(group)
            combined[group].concat(results)
          else
            combined[group] = results
          end
        end

        combined
      end

      # Deep copy a hash to avoid modifying the original
      # @param hash [Hash] The hash to copy
      # @return [Hash] A deep copy of the hash
      def deep_copy(hash)
        Marshal.load(Marshal.dump(hash))
      end
    end
  end
end
