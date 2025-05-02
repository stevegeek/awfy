# frozen_string_literal: true

module Awfy
  module Views
    module IPS
      class CompositeView < CompositeViewBase
        # Initialize child views for delegation
        def setup_child_views
          @summary_view = SummaryView.new(@shell, @options)
          @commits_view = CommitsView.new(@shell, @options)
          @highlights_view = HighlightsView.new(@shell, @options)
        end

        # Generate a table showing test performance across commits
        def test_performance_table(test_label, runtime, sorted_commits, results_by_commit)
          @commits_view.test_performance_table(test_label, runtime, sorted_commits, results_by_commit)
        end

        # Generate a highlights table showing performance trends across commits
        def highlights_table(sorted_commits, results_by_commit)
          @highlights_view.highlights_table(sorted_commits, results_by_commit)
        end
      end
    end
  end
end
