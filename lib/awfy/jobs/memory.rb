# frozen_string_literal: true

require "memory_profiler"

module Awfy
  module Jobs
    class Memory < Base
      def call
        if verbose?
          say "> Memory profiling for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          # Get total number of tests for progress bar
          total_tests = report.tests.size

          if verbose?
            say "> Running #{total_tests} memory profiles", :cyan
          end

          # Create progress bar
          progress_bar = Awfy::Views::ProgressBar.new(
            shell: session.shell,
            total_benchmarks: total_tests,
            ascii_only: config.ascii_only?
          )

          if verbose?
            say "#{group.name}/#{report.name} [#{runtime}] #{total_tests} tests", :cyan
            say
          end

          results = []
          benchmarker.run_tests(report, test_name, output: false) do |test, _|
            if verbose?
              say "# ***"
              say "# #{test.control? ? "Control" : "Test"}: #{test.name}", :green
              say "# ***"
              say
            end

            data = MemoryProfiler.report do
              test.block.call
            end

            data.pretty_print if verbose?

            results << {
              test:,
              data:
            }

            # Update progress
            progress_bar.increment
          end

          # Stop the progress bar
          progress_bar.finish

          # Save results for each test
          results.each do |result|
            result_data = convert_memory_profile_to_data(result[:data])
            results_manager.save_new_result(:memory, group, report, runtime, result[:test], result_data)
          end
        end

        generate_memory_summary if config.show_summary?
      end

      private

      def convert_memory_profile_to_data(result)
        {
          memory: {
            memsize: result.total_allocated_memsize,
            objects: result.total_allocated
          },
          # Individual results, arrays of objects {count: numeric, data: string}
          allocated_memory_by_gem: result.allocated_memory_by_gem,
          retained_memory_by_gem: result.retained_memory_by_gem,
          allocated_memory_by_file: result.allocated_memory_by_file,
          retained_memory_by_file: result.retained_memory_by_file,
          allocated_memory_by_location: result.allocated_memory_by_location,
          retained_memory_by_location: result.retained_memory_by_location,
          allocated_memory_by_class: result.allocated_memory_by_class,
          retained_memory_by_class: result.retained_memory_by_class,
          allocated_objects_by_gem: result.allocated_objects_by_gem,
          retained_objects_by_gem: result.retained_objects_by_gem,
          allocated_objects_by_file: result.allocated_objects_by_file,
          retained_objects_by_file: result.retained_objects_by_file,
          allocated_objects_by_location: result.allocated_objects_by_location,
          retained_objects_by_location: result.retained_objects_by_location,
          allocated_objects_by_class: result.allocated_objects_by_class,
          retained_objects_by_class: result.retained_objects_by_class
        }
      end

      def generate_memory_summary
        results_manager.each_report(:memory) do |results, baseline|
          Views::Memory::SummaryView.new(session:).summary_table(results, baseline)
        end
      end
    end
  end
end
