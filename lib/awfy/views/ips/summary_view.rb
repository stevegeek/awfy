# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      # View for IPS benchmark summary reports
      class SummaryView < BaseView
        # Generate a summary table for IPS results
        # @param report [Array<Hash>] Report metadata
        # @param results [Array<Hash>] Benchmark results
        # @param baseline [Hash] The baseline result for comparison
        def summary_table(report, results, baseline)
          # Process results for comparison
          result_diffs = compute_result_diffs(results, baseline)

          # Sort by iterations (higher is better)
          sorted_results = sort_results(result_diffs)

          # Generate table rows
          rows = generate_table_rows(sorted_results)

          # Generate and display the table
          report_data = report.first
          table_title = table_title(report_data["group"], report_data["report"])
          table = format_table(table_title, ["Branch", "Runtime", "Name", "IPS", "Vs baseline"], rows)

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

        # Sort results based on IPS and sort order
        def sort_results(results)
          results.sort_by do |result|
            factor = (@options.summary_order == "asc") ? 1 : -1
            factor * result[:iter]
          end
        end

        # Generate table rows from results
        def generate_table_rows(results)
          results.map do |result|
            diff_message = format_result_diff(result)
            test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]
            result_stats = Benchmark::IPS::Stats::SD.new(result[:samples])
            [result[:branch], result[:runtime], test_name, humanize_scale(result_stats.central_tendency), diff_message]
          end
        end

        # Format the result difference compared to baseline
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
            "Results displayed in ascending order"
          when "desc"
            "Results displayed in descending order"
          when "leader"
            "Results displayed as a leaderboard (best to worst)"
          end
        end
      end
    end
  end
end
