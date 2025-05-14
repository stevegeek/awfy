# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class SummaryView < BaseView
        def summary_table(results, baseline)
          # Process results for comparison
          result_diffs = result_data_with_diffs(results, baseline)
          sort_order = config.summary_order
          sorted_results = results.sort_by do |result|
            diff_data = result_diffs[result]
            diff_value = if result == baseline || diff_data[:overlaps] || diff_data[:diff_times].nil? || diff_data[:diff_times].zero?
              0  # "same" results
            else
              diff_data[:diff_times] || Float::INFINITY  # Other results by diff, nil diffs last
            end
            [diff_value, -result.timestamp.to_i]  # Negative timestamp for desc order
          end

          # Find max memory value for performance bar scaling
          max_memory = sorted_results.map do |result|
            result.result_data[:allocated_memsize]
          end.max

          # Generate table rows
          rows = generate_table_rows(sorted_results, result_diffs, baseline)

          # Generate and display the table
          result = results.first
          title = table_title(result.group_name, result.report_name)

          headings = [
            Rainbow("Timestamp").bright,
            Rainbow("Branch").bright,
            Rainbow("Runtime").bright,
            Rainbow("Name").bright,
            Rainbow("Allocated Memory").bright,
            Rainbow("Retained Memory").bright,
            Rainbow("Objects").bright,
            Rainbow("Strings").bright,
            Rainbow("Vs test").bright
          ]

          table = if use_modern_style?
            # For modern style, add max values for performance bars
            format_modern_table(
              Rainbow(title).bright,
              headings,
              rows,
              {memory: max_memory}
            )
          else
            # Classic style
            format_table(title, ["Timestamp", "Branch", "Runtime", "Name", "Allocated Memory", "Retained Memory", "Objects", "Strings", "Vs test"], rows)
          end

          # Output the table
          if config.quiet? && config.show_summary?
            puts table
          else
            say table
            say order_description(true)  # true for memory mode
          end
        end

        private

        def result_data_with_diffs(results, baseline)
          baseline_memory = baseline.result_data[:allocated_memsize]

          results.each_with_object({}) do |result, diffs|
            memory = result.result_data[:allocated_memsize]

            overlaps = false  # Memory doesn't have overlaps like IPS
            diff_x = if baseline_memory > memory && baseline_memory > 0
              memory.to_f / baseline_memory  # Ratio < 1 means better (less memory)
            elsif memory > 0
              baseline_memory.to_f / memory  # Ratio < 1 means worse (more memory)
            end

            diffs[result] = {
              overlaps: overlaps,
              diff_times: diff_x&.round(2)
            }
          end
        end

        def generate_table_rows(results, result_diffs, baseline)
          results.map do |result|
            is_baseline = result == baseline
            diff_message = format_result_diff(result, result_diffs[result], baseline)
            test_name = is_baseline ? "(test) #{result.label}" : result.label
            memory_data = result.result_data
            [
              result.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
              result.branch || "unknown",
              result.runtime.value,
              test_name,
              humanize_scale(memory_data[:allocated_memsize]),
              humanize_scale(memory_data[:retained_memsize]),
              humanize_scale(memory_data[:allocated_objects]),
              humanize_scale(memory_data[:allocated_strings]),
              diff_message
            ]
          end
        end

        def format_result_diff(result, diff_data, baseline)
          if result == baseline
            "-"
          elsif diff_data[:diff_times].nil?
            "N/A"
          elsif diff_data[:overlaps] || diff_data[:diff_times].zero?
            "same"
          elsif diff_data[:diff_times] == Float::INFINITY
            "∞"
          elsif diff_data[:diff_times]
            "#{diff_data[:diff_times]} x"
          else
            "?"
          end
        end
      end
    end
  end
end
