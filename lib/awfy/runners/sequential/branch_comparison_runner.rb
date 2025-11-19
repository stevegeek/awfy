# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # BranchComparisonRunner runs benchmarks to compare performance between git branches
      # Each branch is run in a fresh Ruby process to ensure clean environment
      class BranchComparisonRunner < Awfy::Runners::Base
        def run(main_branch, comparison_branch, group = nil, &block)
          start!

          main_results = run_on_branch(main_branch, group)
          comparison_results = run_on_branch(comparison_branch, group)

          all_results = combine_results(main_results, comparison_results)

          if block_given?
            block.call(all_results)
          end

          all_results
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
          cmd << "--runtime=#{session.config.runtime}" if session.config.runtime
          cmd << "--test-time=#{session.config.test_time}" if session.config.test_time
          cmd << "--test-warm-up=#{session.config.test_warm_up}" if session.config.test_warm_up
          cmd << "--storage-backend=#{session.config.storage_backend}" if session.config.storage_backend
          cmd << "--storage-name=#{session.config.storage_name}" if session.config.storage_name
          cmd << "--setup-file-path=#{session.config.setup_file_path}" if session.config.setup_file_path
          cmd << "--tests-path=#{session.config.tests_path}" if session.config.tests_path
          cmd << "--verbose=#{session.config.verbose.value}" if session.config.verbose && session.config.verbose.value > 0
          # Disable summary since we're running without a TTY and will display our own summary
          cmd << "--no-summary"

          # Execute the command
          if session.config.verbose?(VerbosityLevel::DEBUG)
            say "Executing: #{cmd.join(" ")}"
          end

          success = system(*cmd, out: File::NULL, err: File::NULL)
          unless success
            raise "Benchmark command failed in spawned process"
          end

          success
        end

        def run_on_branch(branch, group = nil, report_name = nil, test_name = nil, command_type = nil)
          results = nil

          safe_checkout(branch) do
            say "Running benchmarks on branch: #{branch}" if session.config.verbose?(VerbosityLevel::BASIC)

            cmd_type = command_type || :ips
            run_in_fresh_process(cmd_type, group, report_name, test_name)

            results = load_results(branch)
          end

          results
        end

        def load_results(branch)
          results_directory = session.config.results_directory || "./benchmarks/.awfy_benchmark_results"
          result_files = Dir.glob(File.join(results_directory, "*.json"))
          latest_file = result_files.max_by { |f| File.mtime(f) }

          return {} unless latest_file

          results = JSON.parse(File.read(latest_file))

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

        def combine_results(main_results, comparison_results)
          combined = deep_copy(main_results)

          comparison_results.each do |group, results|
            if combined.key?(group)
              combined[group].concat(results)
            else
              combined[group] = results
            end
          end

          combined
        end

        def deep_copy(hash)
          Marshal.load(Marshal.dump(hash))
        end
      end
    end
  end
end
