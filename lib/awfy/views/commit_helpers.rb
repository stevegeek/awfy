# frozen_string_literal: true

module Awfy
  module Views
    # Common helpers for working with git commits and related views
    module CommitHelpers
      def format_commit_info(commit, commit_message, hash_length = 8, message_length = 22)
        commit_short = commit[0..hash_length - 1]
        commit_msg = commit_message.to_s[0..message_length - 1]
        commit_msg += "..." if commit_message.to_s.length > message_length
        [commit_short, commit_msg]
      end

      def create_baseline_row(commit, commit_message, extra_columns = [])
        commit_short, commit_msg = format_commit_info(commit, commit_message)
        [commit_short, commit_msg, *extra_columns]
      end

      def find_test_result(results_by_commit, commit, runtime, test_label = nil)
        return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]

        if test_label
          results_by_commit[commit][runtime].find do
            r.result_data && r.result_data[:label] == test_label
          end
        else
          # Get the first real test result
          results_by_commit[commit][runtime].find do |r|
            r.result_data && r.result_data[:label]
          end
        end
      end

      def has_runtime?(results_by_commit, runtime)
        results_by_commit.any? { |_, data| data[runtime] }
      end
    end
  end
end
