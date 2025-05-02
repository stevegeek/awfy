# frozen_string_literal: true

module Awfy
  module Views
    # Base class for composite views that delegate to specialized views
    class CompositeViewBase < BaseView
      def initialize(shell, options)
        super
        setup_child_views
      end

      def setup_child_views
        raise NotImplementedError, "Subclasses must implement setup_child_views"
      end

      def summary_table(report, results, baseline)
        @summary_view.summary_table(report, results, baseline)
      end
    end
  end
end
