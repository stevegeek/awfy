# frozen_string_literal: true

module Awfy
  module Jobs
    class Base < Literal::Object
      include Awfy::HasSession

      prop :benchmarker, Awfy::Benchmarker, reader: :private
      prop :results_manager, Awfy::ResultsManager, reader: :private

      prop :group, Suites::Group, reader: :private

      prop :report_name, _Nilable(String), reader: :private
      prop :test_name, _Nilable(String), reader: :private

      def call
        raise NoMethodError, "You must implement the call method in your job class"
      end

      private


      # These hacks allow us to find sometheng in the results from the benchmark tool when it runs in a way that we can
      # only get results async
      CONTROL_MARKER = "[c]"
      TEST_MARKER = "[*]"
      BASELINE_MARKER = "[b]"

      def generate_test_label(test, runtime)
        "[#{runtime}] #{test.control? ? CONTROL_MARKER : TEST_MARKER}#{test.baseline? ? BASELINE_MARKER : ""} #{test.name}"
      end

      def marked_as_control?(test)
        test.label.include?(CONTROL_MARKER)
      end

      def marked_as_test?(test)
        test.label.include?(TEST_MARKER)
      end

      def marked_as_baseline?(test)
        test.label.include?(BASELINE_MARKER)
      end
    end
  end
end
