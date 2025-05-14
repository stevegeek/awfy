# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group_names, _Nilable(_Array(String)), reader: :private
      prop :report_name, _Nilable(String), reader: :private
      prop :test_name, _Nilable(String), reader: :private

      private

      def load_suite!
        suite = Suites::Loader.new(session:, group_names:).load

        # Check if the test suite has tests
        unless suite.tests?
          raise Errors::SuiteEmptyError, "Test suite (in '#{config.tests_path}') has no tests defined..."
        end

        suite
      end
    end
  end
end
