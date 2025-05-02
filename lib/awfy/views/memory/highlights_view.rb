# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class HighlightsView < BaseView
        include CommitHelpers

        def highlights_table(sorted_commits, results_by_commit)
          # Use MRI results for memory comparisons if available, otherwise YJIT
          runtime = select_runtime(results_by_commit)
          baseline_data = extract_baseline_data(sorted_commits, results_by_commit, runtime)

          unless baseline_data
            say "No baseline memory data available for comparison"
            return
          end

          headings = ["Commit", "Description", "Memory Change", "Objects Change"]
          rows = [build_baseline_row(baseline_data)]

          # Process non-baseline commits
          sorted_commits[1..].each do |commit|
            rows << build_commit_row(commit, baseline_data, results_by_commit, runtime)
          end

          # Generate and display the table
          table = format_table("Memory Highlights", headings, rows)
          say "\n\n==== MEMORY HIGHLIGHTS ====\n"
          say table
        end

        private

        def select_runtime(results_by_commit)
          has_runtime?(results_by_commit, :mri) ? :mri : :yjit
        end

        def extract_baseline_data(sorted_commits, results_by_commit, runtime)
          baseline_commit = sorted_commits.first
          baseline_result = find_first_test_with_memory(results_by_commit, baseline_commit, runtime)

          return nil unless baseline_result

          {
            commit: baseline_commit,
            metadata: results_by_commit[baseline_commit][:metadata],
            memory: baseline_result["memory"]["memsize"],
            objects: baseline_result["memory"]["objects"]
          }
        end

        def build_baseline_row(baseline_data)
          commit_short, commit_msg = format_commit_info(
            baseline_data[:commit],
            baseline_data[:metadata][:commit_message],
            8,
            23
          )

          [commit_short, commit_msg, "baseline", "baseline"]
        end

        def build_commit_row(commit, baseline_data, results_by_commit, runtime)
          metadata = results_by_commit[commit][:metadata]
          commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 23)

          current_result = find_first_test_with_memory(results_by_commit, commit, runtime)

          if current_result && current_result["memory"]
            memory_change = format_memory_change(
              current_result["memory"]["memsize"],
              baseline_data[:memory]
            )

            objects_change = format_memory_change(
              current_result["memory"]["objects"],
              baseline_data[:objects]
            )

            [commit_short, commit_msg, memory_change, objects_change]
          else
            [commit_short, commit_msg, "N/A", "N/A"]
          end
        end

        def format_memory_change(current_value, baseline_value)
          if current_value && baseline_value
            # Convert to BigDecimal for precise division
            current_bd = BigDecimal(current_value.to_s)
            baseline_bd = BigDecimal(baseline_value.to_s)
            comparison_ratio = (current_bd / baseline_bd).round(2)
            format_change(comparison_ratio)
          else
            "N/A"
          end
        end

        def find_first_test_with_memory(results_by_commit, commit, runtime)
          return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]

          # Find the first test that has memory data
          results_by_commit[commit][runtime].find do |result|
            result["item"] && result["memory"]
          end
        end
      end
    end
  end
end
