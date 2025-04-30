# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      # View for Memory performance highlights
      class HighlightsView < BaseView
        # Generate a highlights table showing memory trends across commits
        # @param sorted_commits [Array<String>] Sorted list of commit hashes
        # @param results_by_commit [Hash] Results organized by commit
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

          rows = []

          # Show baseline row
          baseline_row = [
            baseline_commit[0..7],
            results_by_commit[baseline_commit][:metadata][:commit_message].to_s[0..22] + "...",
            "baseline",
            "baseline"
          ]

          rows << baseline_row

          # Skip the first one (baseline)
          sorted_commits[1..].each do |commit|
            metadata = results_by_commit[commit][:metadata]
            commit_short = commit[0..7]
            commit_msg = metadata[:commit_message].to_s[0..22] + "..."

            current_result = find_first_test_with_memory(results_by_commit, commit, runtime)

            if current_result && current_result["memory"]
              current_memory = current_result["memory"]["memsize"]
              current_objects = current_result["memory"]["objects"]

              # Memory change
              memory_comparison = if current_memory && baseline_memory
                (current_memory.to_f / baseline_memory).round(2)
              end

              memory_change = if memory_comparison
                if memory_comparison < 1.0
                  "-#{((1 - memory_comparison) * 100).round(1)}%"
                elsif memory_comparison > 1.0
                  "+#{((memory_comparison - 1) * 100).round(1)}%"
                else
                  "No change"
                end
              else
                "N/A"
              end

              # Objects change
              objects_comparison = if current_objects && baseline_objects
                (current_objects.to_f / baseline_objects).round(2)
              end

              objects_change = if objects_comparison
                if objects_comparison < 1.0
                  "-#{((1 - objects_comparison) * 100).round(1)}%"
                elsif objects_comparison > 1.0
                  "+#{((objects_comparison - 1) * 100).round(1)}%"
                else
                  "No change"
                end
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

        def has_runtime?(results_by_commit, runtime)
          results_by_commit.any? { |_, data| data[runtime] }
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
