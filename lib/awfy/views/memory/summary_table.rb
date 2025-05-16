# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class SummaryTable < Table
        def self.build_row(result, is_baseline:, diff_message:, chart:)
          memory_data = result.result_data
          Row.new(
            identifier: result.result_id,
            highlight: is_baseline,
            columns: {
              timestamp: result.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
              branch: result.branch || "?",
              commit_hash: result.commit_hash ? result.commit_hash[0..7] : "?",
              runtime: result.runtime.value,
              control_indicator: result.control? ? "✓" : "",
              test_name: is_baseline ? "(test) #{result.label}" : result.label,
              allocated_memory: memory_data[:allocated_memsize] || 0,
              humanized_allocated: Awfy::Views::ComparisonFormatters.humanize_scale(memory_data[:allocated_memsize]),
              retained_memory: memory_data[:retained_memsize] || 0,
              humanized_retained: Awfy::Views::ComparisonFormatters.humanize_scale(memory_data[:retained_memsize]),
              objects: memory_data[:allocated_objects] || 0,
              humanized_objects: Awfy::Views::ComparisonFormatters.humanize_scale(memory_data[:allocated_objects]),
              strings: memory_data[:allocated_strings] || 0,
              humanized_strings: Awfy::Views::ComparisonFormatters.humanize_scale(memory_data[:allocated_strings]),
              diff: diff_message,
              chart:
            }
          )
        end

        def color_scales
          {allocated_memory: :r, retained_memory: :g, diff: :b}
        end

        def columns
          [
            :timestamp,
            :branch,
            :commit_hash,
            :runtime,
            :control_indicator,
            :test_name,
            :allocated_memory,
            :humanized_allocated,
            :retained_memory,
            :humanized_retained,
            :humanized_objects,
            :humanized_strings,
            :diff,
            :chart
          ]
        end

        def headers
          {
            timestamp: "Timestamp",
            branch: "Branch",
            commit_hash: "Commit",
            runtime: "Runtime",
            control_indicator: "Control",
            test_name: "Name",
            allocated_memory: "Allocated Memory",
            humanized_allocated: "",
            retained_memory: "Retained Memory",
            humanized_retained: "",
            humanized_objects: "Objects",
            humanized_strings: "Strings",
            diff: "vs Test",
            chart: ""
          }
        end

        def order_description
          case config.summary_order
          when "asc"
            "Results displayed in ascending order (lowest memory first)"
          when "desc"
            "Results displayed in descending order (highest memory first)"
          else # Default to "leader"
            "Results displayed as a leaderboard (best to worst)"
          end
        end
      end
    end
  end
end
