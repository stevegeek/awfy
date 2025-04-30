# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      # View for Memory benchmark summary reports
      class SummaryView < BaseView
        # Generate a summary table for memory results
        # @param report [Array<Hash>] Report metadata
        # @param results [Array<Hash>] Benchmark results
        # @param baseline [Hash] The baseline result for comparison
        def summary_table(report, results, baseline)
          # Process results for comparison
          result_diffs = compute_result_diffs(results, baseline)

          # Sort by memory usage (lower is better)
          sorted_results = sort_results(result_diffs)

          # Generate table rows
          rows = generate_table_rows(sorted_results)

          # Generate and display the table
          report_data = report.first
          table_title = table_title(report_data["group"], report_data["report"])
          table = format_table(
            table_title,
            ["Branch", "Runtime", "Name", "Allocated Mem", "Retained Mem", "Objects", "Strings", "Vs baseline"],
            rows
          )

          # Output the table
          if @options.quiet? && show_summary?
            puts table
          else
            say table
            say order_description
          end
        end

        private

        # Compute result differences compared to baseline
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

        # Sort results based on memory usage and sort order
        def sort_results(results)
          results.sort_by do |result|
            factor = (@options.summary_order == "asc") ? 1 : -1
            # For memory, lower is better so we invert the factor
            -factor * (result[:measurement]&.allocated || 0)
          end
        end

        # Generate table rows from results
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

        # Format the memory difference compared to baseline
        def format_memory_diff(result)
          if result[:is_baseline]
            "-"
          elsif !result[:memory_diff]
            "N/A"
          elsif result[:memory_diff] == 1.0
            "same"
          elsif result[:memory_diff] < 1.0
            "#{((1 - result[:memory_diff]) * 100).round(1)}% better"
          else
            "#{((result[:memory_diff] - 1) * 100).round(1)}% worse"
          end
        end

        # Generate a table title
        def table_title(group, report = nil, test = nil)
          tests = [group, report, test].compact
          return "Run: (all)" if tests.empty?
          "Run: #{tests.join("/")}"
        end

        # Generate a description of the sort order
        def order_description
          case @options.summary_order
          when "asc"
            "Results displayed in ascending order (lowest memory first)"
          when "desc"
            "Results displayed in descending order (highest memory first)"
          when "leader"
            "Results displayed as a leaderboard (best to worst)"
          end
        end
      end
    end
  end
end
