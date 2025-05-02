# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class SummaryView < BaseView
        def summary_table(report, results, baseline)
          # Process results for comparison
          result_diffs = compute_result_diffs(results, baseline)

          # Sort by memory usage (lower is better)
          # For memory, lower is better so we pass true to invert
          sorted_results = sort_results(
            result_diffs,
            ->(result) { result[:measurement]&.allocated || 0 },
            true
          )

          # Generate table rows
          rows = generate_table_rows(sorted_results)

          # Generate and display the table
          report_data = report.first
          title = table_title(report_data["group"], report_data["report"])
          table = format_table(
            title,
            ["Branch", "Runtime", "Name", "Allocated Mem", "Retained Mem", "Objects", "Strings", "Vs baseline"],
            rows
          )

          # Output the table
          if @options.quiet? && show_summary?
            puts table
          else
            say table
            say order_description(true)
          end
        end

        private

        def compute_result_diffs(results, baseline)
          baseline_allocated = baseline[:measurement]&.allocated

          results.map do |result|
            allocated = result[:measurement]&.allocated
            diff_ratio = if baseline_allocated && allocated && baseline_allocated > 0
              (allocated.to_f / baseline_allocated).round(2)
            end

            result.merge(memory_diff: diff_ratio)
          end
        end

        def generate_table_rows(results)
          results.map do |result|
            measurement = result[:measurement]
            diff_message = format_memory_diff(result)
            test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]

            [
              result[:branch],
              result[:runtime],
              test_name,
              humanize_scale(measurement&.allocated || 0),
              humanize_scale(measurement&.retained || 0),
              humanize_scale(measurement&.objects&.allocated || 0),
              humanize_scale(measurement&.strings&.allocated || 0),
              diff_message
            ]
          end
        end

        def format_memory_diff(result)
          if result[:is_baseline]
            "-"
          elsif !result[:memory_diff]
            "N/A"
          else
            bd_memory_diff = BigDecimal(result[:memory_diff].to_s)
            bd_one = BigDecimal("1.0")
            if bd_memory_diff == bd_one
              "same"
            elsif bd_memory_diff < bd_one
              "%.1f%% better" % ((bd_one - bd_memory_diff) * 100).round(1)
            else
              "%.1f%% worse" % ((bd_memory_diff - bd_one) * 100).round(1)
            end
          end
        end
      end
    end
  end
end
