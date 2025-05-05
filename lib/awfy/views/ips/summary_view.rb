# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class SummaryView < BaseView
        def summary_table(report, results, baseline)
          # Process results for comparison
          result_diffs = compute_result_diffs(results, baseline)

          # Sort by iterations (higher is better)
          sorted_results = sort_results(result_diffs, ->(result) { result[:iter] })

          # Find max IPS value for performance bar scaling
          max_ips = sorted_results.map do |result|
            result_stats = Benchmark::IPS::Stats::SD.new(result[:samples])
            result_stats.central_tendency
          end.max

          # Generate table rows
          rows = generate_table_rows(sorted_results)

          # Generate and display the table
          report_data = report.first
          title = table_title(report_data["group"], report_data["report"])

          table = if use_modern_style?
            # For modern style, add max values for performance bars
            format_modern_table(
              Rainbow(title).bright,
              [
                Rainbow("Branch").bright,
                Rainbow("Runtime").bright,
                Rainbow("Name").bright,
                Rainbow("IPS").bright,
                Rainbow("Vs baseline").bright
              ],
              rows,
              {ips: max_ips}
            )
          else
            # Classic style
            format_table(title, ["Branch", "Runtime", "Name", "IPS", "Vs baseline"], rows)
          end

          # Output the table
          if @options.quiet? && show_summary?
            puts table
          else
            say table
            say order_description
          end
        end

        private

        def compute_result_diffs(results, baseline)
          results.map do |result|
            baseline_stats = Benchmark::IPS::Stats::SD.new(baseline[:samples])
            result_stats = Benchmark::IPS::Stats::SD.new(result[:samples])
            overlaps = result_stats.overlaps?(baseline_stats)
            diff_x = if baseline_stats.central_tendency > result_stats.central_tendency
              -1.0 * result_stats.speedup(baseline_stats).first
            else
              result_stats.slowdown(baseline_stats).first
            end
            result.merge(
              overlaps: overlaps,
              diff_times: diff_x.round(2)
            )
          end
        end

        def generate_table_rows(results)
          results.map do |result|
            diff_message = format_result_diff(result)
            test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]
            result_stats = Benchmark::IPS::Stats::SD.new(result[:samples])
            [result[:branch], result[:runtime], test_name, humanize_scale(result_stats.central_tendency), diff_message]
          end
        end

        def format_result_diff(result)
          if result[:is_baseline]
            "-"
          elsif result[:overlaps] || result[:diff_times].zero?
            "same"
          elsif result[:diff_times] == Float::INFINITY
            "∞"
          elsif result[:diff_times]
            "#{result[:diff_times]} x"
          else
            "?"
          end
        end
      end
    end
  end
end
