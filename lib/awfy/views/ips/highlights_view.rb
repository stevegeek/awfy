# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class HighlightsView < BaseView
        include CommitHelpers

        def highlights_table(sorted_commits, results_by_commit)
          # Define headings based on available runtimes
          headings = ["Commit", "Description"]

          # Add runtime fields if we have them
          if has_runtime?(results_by_commit, :mri)
            headings << "MRI IPS Change"
          end

          if has_runtime?(results_by_commit, :yjit)
            headings << "YJIT IPS Change"
          end

          if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
            headings << "YJIT vs MRI"
          end

          # Get baseline data
          baseline_commit = sorted_commits.first
          baseline_mri_ips = get_first_test_ips(results_by_commit, baseline_commit, :mri)
          baseline_yjit_ips = get_first_test_ips(results_by_commit, baseline_commit, :yjit)

          # Prepare baseline row
          metadata = results_by_commit[baseline_commit][:metadata]
          commit_short, commit_msg = format_commit_info(baseline_commit, metadata[:commit_message], 8, 23)
          baseline_row = [commit_short, commit_msg]

          # Add runtime baseline columns
          if has_runtime?(results_by_commit, :mri)
            baseline_row << "baseline"
          end

          if has_runtime?(results_by_commit, :yjit)
            baseline_row << "baseline"
          end

          # Add YJIT vs MRI comparison for baseline
          if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
            baseline_row << if baseline_mri_ips && baseline_yjit_ips
              "#{(baseline_yjit_ips / baseline_mri_ips).round(2)}x"
            else
              "N/A"
            end
          end

          rows = [baseline_row]

          # Skip the first one (baseline)
          sorted_commits[1..].each do |commit|
            metadata = results_by_commit[commit][:metadata]
            commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 23)

            row = [commit_short, commit_msg]

            # MRI IPS change
            if has_runtime?(results_by_commit, :mri)
              current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)

              if current_mri_ips && baseline_mri_ips
                ips_ratio = (current_mri_ips / baseline_mri_ips).round(2)
                mri_change = format_change(ips_ratio)
                row << mri_change
              else
                row << "N/A"
              end
            end

            # YJIT IPS change
            if has_runtime?(results_by_commit, :yjit)
              current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)

              if current_yjit_ips && baseline_yjit_ips
                ips_ratio = (current_yjit_ips / baseline_yjit_ips).round(2)
                yjit_change = format_change(ips_ratio)
                row << yjit_change
              else
                row << "N/A"
              end
            end

            # YJIT vs MRI for this commit
            if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
              current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)
              current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)

              if current_mri_ips && current_yjit_ips
                ratio = (current_yjit_ips / current_mri_ips).round(2)
                row << "#{ratio}x"
              else
                row << "N/A"
              end
            end

            rows << row
          end

          # Generate and display the table
          table = format_table("Performance Highlights", headings, rows)

          say "\n\n==== HIGHLIGHTS ====\n"
          say table
        end

        private

        def get_first_test_ips(results_by_commit, commit, runtime)
          result = find_test_result(results_by_commit, commit, runtime)
          result ? result["ips"] : nil
        end
      end
    end
  end
end
