# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class CompositeView < CompositeViewBase
        def setup_child_views
          @summary_view = SummaryView.new(@shell, @options)
          @commits_view = CommitsView.new(@shell, @options)
          @highlights_view = HighlightsView.new(@shell, @options)
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
