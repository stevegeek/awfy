# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class HighlightsView < BaseView
        include CommitHelpers

        def highlights_table(sorted_commits, results_by_commit)
          headings = build_table_headings(results_by_commit)

          baseline_data = extract_baseline_data(sorted_commits, results_by_commit)
          rows = [build_baseline_row(baseline_data, results_by_commit)]

          # Process non-baseline commits
          sorted_commits[1..].each do |commit|
            rows << build_commit_row(commit, baseline_data, results_by_commit)
          end

          # Generate and display the table
          table = format_table("Performance Highlights", headings, rows)

          say "\n\n==== HIGHLIGHTS ====\n"
          say table
        end

        private

        def extract_baseline_data(sorted_commits, results_by_commit)
          baseline_commit = sorted_commits.first
          {
            commit: baseline_commit,
            metadata: results_by_commit[baseline_commit][:metadata],
            mri_ips: get_first_test_ips(results_by_commit, baseline_commit, :mri),
            yjit_ips: get_first_test_ips(results_by_commit, baseline_commit, :yjit)
          }
        end

        def build_table_headings(results_by_commit)
          headings = ["Commit", "Description"]

          headings << "MRI IPS Change" if has_runtime?(results_by_commit, :mri)
          headings << "YJIT IPS Change" if has_runtime?(results_by_commit, :yjit)

          # Add YJIT vs MRI comparison heading if both runtimes exist
          if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
            headings << "YJIT vs MRI"
          end

          headings
        end

        def build_baseline_row(baseline_data, results_by_commit)
          commit_short, commit_msg = format_commit_info(
            baseline_data[:commit],
            baseline_data[:metadata][:commit_message],
            8,
            23
          )

          row = [commit_short, commit_msg]

          # Add runtime baseline columns
          row << "baseline" if has_runtime?(results_by_commit, :mri)
          row << "baseline" if has_runtime?(results_by_commit, :yjit)

          # Add YJIT vs MRI comparison for baseline
          if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
            row << format_runtime_comparison(baseline_data[:mri_ips], baseline_data[:yjit_ips])
          end

          row
        end

        def build_commit_row(commit, baseline_data, results_by_commit)
          metadata = results_by_commit[commit][:metadata]
          commit_short, commit_msg = format_commit_info(commit, metadata[:commit_message], 8, 23)

          row = [commit_short, commit_msg]

          # Add MRI IPS change column if MRI runtime exists
          if has_runtime?(results_by_commit, :mri)
            current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)
            row << format_ips_change(current_mri_ips, baseline_data[:mri_ips])
          end

          # Add YJIT IPS change column if YJIT runtime exists
          if has_runtime?(results_by_commit, :yjit)
            current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)
            row << format_ips_change(current_yjit_ips, baseline_data[:yjit_ips])
          end

          # Add YJIT vs MRI comparison if both runtimes exist
          if has_runtime?(results_by_commit, :mri) && has_runtime?(results_by_commit, :yjit)
            current_mri_ips = get_first_test_ips(results_by_commit, commit, :mri)
            current_yjit_ips = get_first_test_ips(results_by_commit, commit, :yjit)
            row << format_runtime_comparison(current_mri_ips, current_yjit_ips)
          end

          row
        end

        def format_runtime_comparison(mri_ips, yjit_ips)
          if mri_ips && yjit_ips
            # Convert to BigDecimal for precise division
            yjit_bd = BigDecimal(yjit_ips.to_s)
            mri_bd = BigDecimal(mri_ips.to_s)
            ratio = (yjit_bd / mri_bd).round(2)
            "%.1fx" % ratio
          else
            "N/A"
          end
        end

        def format_ips_change(current_ips, baseline_ips)
          if current_ips && baseline_ips
            # Convert to BigDecimal for precise division
            current_bd = BigDecimal(current_ips.to_s)
            baseline_bd = BigDecimal(baseline_ips.to_s)
            ips_ratio = (current_bd / baseline_bd).round(2)
            format_change(ips_ratio)
          else
            "N/A"
          end
        end

        def get_first_test_ips(results_by_commit, commit, runtime)
          result = find_test_result(results_by_commit, commit, runtime)
          result ? result["ips"] : nil
        end
      end
    end
  end
end
