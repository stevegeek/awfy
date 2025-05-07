# frozen_string_literal: true

module Awfy
  module Commands
    class Suite < Base
      def list
        suite = load_suite!

        suite.groups.each do |group|
          view = Views::ListView.new(session:)
          if session.config.list
            view.display_group(group)
          else
            view.display_table(group)
          end
        end
      end

      def run
        Runners.immediate(suite: load_suite!, session:).run do |group|
          Jobs::RunGroup.new(session:, group:, benchmarker: Benchmarker.new(session:, result_manager:))
        end
      end

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
