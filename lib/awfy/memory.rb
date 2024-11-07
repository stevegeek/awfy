# frozen_string_literal: true

module Awfy
  class Memory < Command
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
      read_reports_for_summary("memory") do |report, results, baseline|
        result_diffs = results.map do |result|
          overlaps = result[:total_allocated_memory] == baseline[:total_allocated_memory] && result[:total_retained_memory] == baseline[:total_retained_memory]
          diff_x = if baseline[:total_allocated_memory].zero? && !result[:total_allocated_memory].zero?
            Float::INFINITY
          elsif baseline[:total_allocated_memory].zero?
            0.0
          elsif baseline[:total_allocated_memory] > result[:total_allocated_memory]
            -1.0 * result[:total_allocated_memory] / baseline[:total_allocated_memory]
          else
            result[:total_allocated_memory].to_f / baseline[:total_allocated_memory]
          end
          retained_diff_x = if baseline[:total_retained_memory].zero? && !result[:total_retained_memory].zero?
            Float::INFINITY
          elsif baseline[:total_retained_memory].zero?
            0.0
          elsif baseline[:total_retained_memory] > result[:total_retained_memory]
            -1.0 * result[:total_retained_memory] / baseline[:total_retained_memory]
          else
            result[:total_retained_memory].to_f / baseline[:total_retained_memory]
          end
          result.merge(
            overlaps: overlaps,
            diff_times: diff_x.round(2),
            retained_diff_times: retained_diff_x.round(2)
          )
        end

        # Sort by allocations (lower is better)
        result_diffs.sort_by! do |result|
          factor = options.summary_order == "desc" ? -1 : 1
          factor * result[:diff_times]
        end

        rows = result_diffs.map do |result|
          diff_message = result_diff_message(result)
          retained_message = result_diff_message(result, :retained_diff_times)
          test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]
          [result[:branch], result[:runtime], test_name, humanize_scale(result[:total_allocated_memory]), diff_message, humanize_scale(result[:total_retained_memory]), retained_message]
        end

        output_summary_table(report, rows, "Branch", "Runtime", "Name", "Total Allocations", "Vs baseline", "Total Retained", "Vs baseline")
      end
    end
  end
end
