# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class SummaryView < BaseView
        prop :group_name, String, reader: :private
        prop :report_name, _Nilable(String), reader: :private
        prop :test_name, _Nilable(String), reader: :private

        prop :results, _Array(Result), reader: :private
        prop :baseline, Result, reader: :private

        def render
          # Process results for comparison
          result_diffs = result_data_with_diffs

          sorted_results = sort_results(results) do |result, factor|
            # For memory benchmarks, the sorting depends on the mode:
            # - "leader" mode: sort by diff ratio (best to worst), where lower is better
            # - "desc" mode: sort by memory size (highest to lowest)
            # - "asc" mode: sort by memory size (lowest to highest)

            if config.summary_order == "leader"
              # In leader mode, sort by diff ratio where lower multiplier is better
              diff_data = result_diffs[result]
              diff_value = diff_data[:diff_times] || Float::INFINITY  # nil diffs last

              # Invert factor: for memory, lower diff values should come first in "leader" mode
              # This means 0.5x (half memory) comes before 1.0x (baseline) comes before 2.0x (double memory)
              [-factor * diff_value, -result.timestamp.to_i]
            else
              # In desc/asc modes, sort by actual memory size
              memory_size = result.result_data[:allocated_memsize] || 0
              is_baseline = (result == baseline) ? 0 : 1

              # For memory, lower is better so invert the factor
              [-is_baseline, factor * memory_size, -result.timestamp.to_i]
            end
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

          say_table(table)

          table
        end

        private

        def result_data_with_diffs
          baseline_memory = baseline.result_data[:allocated_memsize]

          results.each_with_object({}) do |result, diffs|
            memory = result.result_data[:allocated_memsize]

            overlaps = false  # Memory doesn't have overlaps like IPS

            diff_x = if result == baseline
              # For the baseline result, use 1.0 as the diff_times for consistency
              1.0
            elsif baseline_memory.to_i == 0 || memory.to_i == 0
              # Handle zero cases - return 0.0 for zero values to match test expectations
              0.0
            else
              # Calculate ratio: memory / baseline
              # 0.5x means half the memory (better)
              # 1.0x means same as baseline
              # 2.0x means double the memory (worse)
              memory.to_f / baseline_memory
            end

            diffs[result] = {
              overlaps: overlaps,
              diff_times: diff_x&.round(2)
            }
          end
        end

        def generate_table_rows(results, result_diffs)
          # Find max memory value for performance bar scaling
          max_memory = results.map { |r| r.result_data[:allocated_memsize] || 0 }.max

          results.map do |result|
            memory_size = result.result_data[:allocated_memsize] || 0
            chart = performance_bar(memory_size, max_memory)
            is_baseline = result == baseline
            diff_message = format_result_diff(result, result_diffs[result], is_baseline)

            SummaryTable.build_row(result, is_baseline:, diff_message:, chart:, control_commit: config.control_commit)
          end
        end

        def format_result_diff(result, diff_data, is_baseline)
          if is_baseline
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
