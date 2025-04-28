# frozen_string_literal: true

module Awfy
  module Commands
    class Memory < Base
      def benchmark(group, report_name, test_name)
        if verbose?
          say "> Memory profiling for:"
          say "> #{group[:name]}...", :cyan
        end
        execute_report(group, report_name) do |report, runtime|
          results = []
          execute_tests(report, test_name) do |test, _|
            data = MemoryProfiler.report do
              test[:block].call
            end
            test_label = generate_test_label(test, runtime)
            results << {
              label: test_label,
              control: test[:control],
              data: data
            }
            data.pretty_print if verbose?
          end

          save_to(:memory, group, report, runtime) do |file_name|
            save_memory_profile_report_to_file(file_name, results)
          end
        end

        generate_memory_summary if show_summary?
      end

      private

      def load_memory_results_json(file_name)
        JSON.parse(File.read(file_name)).map { _1.transform_keys(&:to_sym) }
      end

      def save_memory_profile_report_to_file(file_name, results)
        data = results.map do |label_and_data|
          result = label_and_data[:data]
          {
            label: label_and_data[:label],
            control: !!label_and_data[:control],
            total_allocated_memory: result.total_allocated_memsize,
            total_retained_memory: result.total_retained_memsize,
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
        File.write(file_name, data.to_json)
      end

      def generate_memory_summary
        # Get the Memory view
        view = Views::ViewFactory.create(:memory, shell, options)
        
        # Process reports and use the view to display
        read_reports_for_summary("memory") do |report, results, baseline|
          # Calculate and add measurements for each result
          results.each do |result|
            # Create a fake Benchmark::Memory measurement structure
            result[:measurement] = Struct.new(
              :allocated, :retained, :objects, :strings
            ).new(
              result[:total_allocated_memory],
              result[:total_retained_memory],
              Struct.new(:allocated).new(0), # We don't have this data in the current format
              Struct.new(:allocated).new(0)  # We don't have this data in the current format
            )
          end
          
          view.summary_table(report, results, baseline)
        end
      end
    end
  end
end