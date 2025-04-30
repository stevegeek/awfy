# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      # Composite view for Memory that delegates to specialized views
      class CompositeView < BaseView
        def initialize(shell, options)
          super
          @summary_view = SummaryView.new(shell, options)
          @commits_view = CommitsView.new(shell, options)
          @highlights_view = HighlightsView.new(shell, options)
        end

        def summary_table(report, results, baseline)
          @summary_view.summary_table(report, results, baseline)
        end

        def test_memory_table(test_label, runtime, sorted_commits, results_by_commit)
          @commits_view.test_memory_table(test_label, runtime, sorted_commits, results_by_commit)
        end

        def memory_highlights_table(sorted_commits, results_by_commit)
          @highlights_view.highlights_table(sorted_commits, results_by_commit)
        end
      end
    end
  end
end
