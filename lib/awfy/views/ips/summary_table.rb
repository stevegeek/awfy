# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class SummaryTable < Table
        def self.build_row(result, is_baseline:, diff_message:, chart:)
          Row.new(
            identifier: result.result_id,
            highlight: is_baseline,
            columns: {
              timestamp: result.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
              branch: result.branch || "?",
              commit_hash: result.commit_hash ? result.commit_hash[0..7] : "?",
              runtime: result.runtime.value,
              control_indicator: result.control? ? "✓" : "",
              # baseline_indicator: is_baseline ? "✓" : "",
              test_name: result.label,
              value: result.central_tendency,
              humanized_value: humanize_scale(result.central_tendency),
              diff: diff_message,
              chart:
            }
          )
        end

        def color_scales
          {value: :rg, diff: :b}
        end

        def columns
          headers.keys
        end

        def headers
          {
            timestamp: "Timestamp",
            branch: "Branch",
            commit_hash: "Commit",
            runtime: "Runtime",
            control_indicator: "Control",
            # baseline_indicator: "Baseline",
            test_name: "Name",
            value: "IPS",
            humanized_value: "",
            diff: "vs Test",
            chart: ""
          }
        end
      end
    end
  end
end
