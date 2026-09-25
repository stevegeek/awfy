# frozen_string_literal: true

module Awfy
  module Suites
    class Report < Literal::Data
      prop :name, String
      prop :tests, _Array(Test)
      prop :hooks, Suites::Hooks, default: -> { Suites::Hooks.new }
      prop :assertions, _Array(Suites::Assertion), default: -> { [] }

      def <<(test)
        @tests << test
      end

      def tests?
        @tests.any?
      end

      def size
        @tests.size
      end

      def without_control_tests
        self.class.new(**to_h, tests: @tests.reject(&:control?))
      end

      # The assertions that apply to this report: its own, and those of its group whose metric
      # it does not assert itself.
      def assertions_within(group)
        own_metrics = @assertions.map(&:metric)
        group.assertions.reject { own_metrics.include?(it.metric) } + @assertions
      end

      def tests_sorted_by_type(test_name: nil)
        filtered_tests = test_name ? tests.select { |t| t.name == test_name } : tests
        filtered_tests.sort { it.control? ? -1 : 1 }
      end
    end
  end
end
