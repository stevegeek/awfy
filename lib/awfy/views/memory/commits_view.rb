# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class CommitsView < BaseView
        include CommitHelpers

        def test_memory_table(test_label, runtime, sorted_commits, results_by_commit)
          # Get baseline memory (first commit for this test)
          first_commit = sorted_commits.first
          baseline_result = find_test_result(results_by_commit, first_commit, runtime, test_label)
          baseline_memory = (baseline_result && baseline_result["memory"]) ? baseline_result["memory"]["memsize"] : nil

          rows = []

          sorted_commits.each do |commit|
            # Get commit metadata
            metadata = results_by_commit[commit][:metadata]
            commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 28)

            # Find this test in the results
            result = find_test_result(results_by_commit, commit, runtime, test_label)

            if result && result["memory"]
              bytes = result["memory"]["memsize"]
              objects = result["memory"]["objects"]

              comparison = if baseline_memory && bytes && commit != first_commit
                ratio = (bytes.to_f / baseline_memory)
                format_comparison(ratio, false)
              else
                "baseline"
              end

              rows << [commit_short, commit_msg, humanize_scale(bytes), humanize_scale(objects), comparison]
            else
              rows << [commit_short, commit_msg, "N/A", "N/A", "N/A"]
            end
          end

          # Generate and display the table
          table_title = "#{test_label} (#{runtime.to_s.upcase}, memory usage)"
          table = format_table(table_title, ["Commit", "Description", "Bytes", "Objects", "vs Baseline"], rows)

          say table
        end
      end
    end
  end
end
