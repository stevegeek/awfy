# frozen_string_literal: true

module Awfy
  module Suites
    class Report < Literal::Data
      prop :name, String
      prop :tests, _Array(Test)

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
        self.class.new(@tests.reject(&:control?))
      end

      def tests_sorted_by_type(test_name: nil)
        filtered_tests = test_name ? tests.select { |t| t.name == test_name } : tests
        filtered_tests.sort { it.control? ? -1 : 1 }
      end
    end
  end
end
