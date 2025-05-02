# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class HighlightsView < BaseView
        include CommitHelpers

        def highlights_table(sorted_commits, results_by_commit)
          headings = ["Commit", "Description", "Memory Change", "Objects Change"]

          # Get baseline data
          baseline_commit = sorted_commits.first

          # Use MRI results for memory comparisons
          runtime = has_runtime?(results_by_commit, :mri) ? :mri : :yjit
          baseline_result = find_first_test_with_memory(results_by_commit, baseline_commit, runtime)

          if !baseline_result
            say "No baseline memory data available for comparison"
            return
          end

          baseline_memory = baseline_result["memory"]["memsize"]
          baseline_objects = baseline_result["memory"]["objects"]

          # Prepare baseline row
          metadata = results_by_commit[baseline_commit][:metadata]
          commit_short, commit_msg = format_commit_info(baseline_commit, metadata[:commit_message], 8, 23)

          # Create baseline row with default "baseline" values for memory and objects
          baseline_row = [commit_short, commit_msg, "baseline", "baseline"]
          rows = [baseline_row]

          # Skip the first one (baseline)
          sorted_commits[1..].each do |commit|
            metadata = results_by_commit[commit][:metadata]
            commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 23)

            current_result = find_first_test_with_memory(results_by_commit, commit, runtime)

            if current_result && current_result["memory"]
              current_memory = current_result["memory"]["memsize"]
              current_objects = current_result["memory"]["objects"]

              # Memory change
              memory_comparison = if current_memory && baseline_memory
                (current_memory.to_f / baseline_memory).round(2)
              end

              memory_change = if memory_comparison
                format_change(memory_comparison)
              else
                "N/A"
              end

              # Objects change
              objects_comparison = if current_objects && baseline_objects
                (current_objects.to_f / baseline_objects).round(2)
              end

              objects_change = if objects_comparison
                format_change(objects_comparison)
              else
                "N/A"
              end

              rows << [commit_short, commit_msg, memory_change, objects_change]
            else
              rows << [commit_short, commit_msg, "N/A", "N/A"]
            end
          end

          # Generate and display the table
          table = format_table("Memory Highlights", headings, rows)

          say "\n\n==== MEMORY HIGHLIGHTS ====\n"
          say table
        end

        private

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
