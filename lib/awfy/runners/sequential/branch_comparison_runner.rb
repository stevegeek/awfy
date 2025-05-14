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
