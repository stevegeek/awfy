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

      def run(report_name = nil, test_name = nil)
        results_manager = Awfy::ResultsManager.new(session:)
        Runners.create(suite: load_suite!, session:).run do |group|
          Jobs::RunGroup.new(session:, group:, report_name:, test_name:, benchmarker: Benchmarker.new(session:), results_manager:)
        end
      end
    end
  end
end
