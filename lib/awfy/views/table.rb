# frozen_string_literal: true

module Awfy
  module Views
    class Table < Literal::Object
      include HasSession
      extend ComparisonFormatters

      prop :group_name, String, reader: :private
      prop :report_name, _Nilable(String), reader: :private
      prop :test_name, _Nilable(String), reader: :private

      prop :rows, _Array(Row), reader: :public

      def title
        tests = [group_name, report_name, test_name].compact
        return "Run: (all)" if tests.empty?

        "Run: #{tests.join("/")}"
      end

      def order_description
        case config.summary_order
        when "asc"
          "Results displayed in ascending order"
        when "desc"
          "Results displayed in descending order"
        else # Default to "leader"
          "Results displayed as a leaderboard (best to worst)"
        end
      end

      def theme
        case config.color
        when ColorMode::DARK
          :dark
        when ColorMode::LIGHT
          :light
        when ColorMode::ANSI
          :ansi
        end
      end

      def headers
        # Default is to work out implicitly
      end

      def columns
        # Default is to render all columns
      end

      def mark
        # Mark the baseline is the default
        -> { it.highlight? }
      end

      def color_scales
        # no scales by default
      end
    end
  end
end
