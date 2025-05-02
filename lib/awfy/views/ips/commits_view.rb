# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class CommitsView < BaseView
        include CommitHelpers

        def test_performance_table(test_label, runtime, sorted_commits, results_by_commit)
          # Get baseline IPS (first commit for this test)
          first_commit = sorted_commits.first
          baseline_result = find_test_result(results_by_commit, first_commit, runtime, test_label)
          baseline_ips = baseline_result ? baseline_result["ips"] : nil

          rows = []

          sorted_commits.each do |commit|
            # Get commit metadata
            metadata = results_by_commit[commit][:metadata]
            commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 28)

            # Find this test in the results
            result = find_test_result(results_by_commit, commit, runtime, test_label)

            if result
              ips = result["ips"]

              comparison = if baseline_ips && ips && commit != first_commit
                ratio = (ips / baseline_ips)
                format_comparison(ratio, true)
              else
                "baseline"
              end

              rows << [commit_short, commit_msg, humanize_scale(ips), comparison]
            else
              rows << [commit_short, commit_msg, "N/A", "N/A"]
            end
          end

          # Generate and display the table
          table_title = "#{test_label} (#{runtime.to_s.upcase}, iterations per second)"
          table = format_table(table_title, ["Commit", "Description", "IPS", "vs Baseline"], rows)

          say table
        end
      end
    end
  end
end
