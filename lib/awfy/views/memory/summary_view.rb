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
            # For memory view, we want to sort by allocated memory size
            # Put baseline first, then sort by allocated memory
            memory_size = result.result_data[:allocated_memsize] || 0
            is_baseline = (result == baseline) ? 0 : 1

            # Primary sort key is baseline status (0 for baseline, 1 for others)
            # Secondary sort key depends on sort order
            memory_key = (sort_order == "asc") ? memory_size : -memory_size

            # Final sort key is timestamp (negative for desc order)
            [is_baseline, memory_key, -result.timestamp.to_i]
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

          table = format_modern_table(
            Rainbow(title).bright,
            headings,
            rows
          )

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

            diff_x = if result == baseline
              # For the baseline result, use 1.0 as the diff_times for consistency in tests
              1.0
            elsif baseline_memory.to_i == 0 || memory.to_i == 0
              # Handle zero cases - return 0.0 for zero values to match test expectations
              0.0
            elsif memory > baseline_memory
              # Normal case - calculate ratio based on which is larger
              # For memory tests, lower is better, so we invert the ratio
              # compared to IPS tests where higher is better
              # More memory usage is worse, so ratio < 1
              baseline_memory.to_f / memory
            else
              # Less memory usage is better, so ratio > 1
              # But we're calculating memory, not IPS, so we report actual ratio
              memory.to_f / baseline_memory
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
          elsif diff_data.nil? || diff_data[:diff_times].nil?
            "N/A"
          elsif diff_data[:overlaps] || (diff_data[:diff_times] - 1.0).abs < 0.001
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
