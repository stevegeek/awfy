# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class SummaryView < BaseView
        prop :group_name, String, reader: :private
        prop :report_name, _Nilable(String), reader: :private
        prop :test_name, _Nilable(String), reader: :private

        prop :results, _Array(IPSResult), reader: :private
        prop :baseline, IPSResult, reader: :private

        def render
          # Process results for comparison
          result_diffs = result_data_with_diffs

          # TODO: account for sort switch, see  sort_results method
          sorted_results = results.sort_by do |result|
            diff_data = result_diffs[result]
            diff_value = if result == baseline || diff_data[:overlaps] || diff_data[:diff_times].zero?
              0  # "same" results
            else
              diff_data[:diff_times] || Float::INFINITY  # Other results by diff, nil diffs last
            end
            [diff_value, -result.timestamp.to_i]  # Negative timestamp for desc order
          end

          # Generate table row instances
          rows = generate_table_rows(sorted_results, result_diffs)

          table = SummaryTable.new(
            session:,
            group_name:,
            report_name:,
            test_name:,
            rows:
          )

          say say_table(table)
        end

        private

        def result_data_with_diffs
          baseline_data = baseline.result_data
          baseline_stats = Benchmark::IPS::Stats::SD.new(baseline_data[:samples])

          results.each_with_object({}) do |result, diffs|
            result_stats = Benchmark::IPS::Stats::SD.new(result.result_data[:samples])
            overlaps = result_stats.overlaps?(baseline_stats)
            diff_x = if baseline_stats.central_tendency > result_stats.central_tendency
              -1.0 * result_stats.speedup(baseline_stats).first
            else
              result_stats.slowdown(baseline_stats).first
            end

            diffs[result] = {
              overlaps: overlaps,
              diff_times: diff_x.round(2)
            }
          end
        end

        def generate_table_rows(results, result_diffs)
          # Find max IPS value for performance bar scaling
          max_ips = results.map(&:central_tendency).max
          results.map do |result|
            chart = performance_bar(result.central_tendency, max_ips)
            is_baseline = result == baseline
            diff_message = format_result_diff(result, result_diffs[result])
            SummaryTable.build_row(result, is_baseline:, diff_message:, chart:)
          end
        end

        def format_result_diff(result, diff_data)
          if result == baseline
            "-"
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
