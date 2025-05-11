# frozen_string_literal: true

module Awfy
  module Commands
    class IPS < Base
      def run
        results_manager = Awfy::ResultsManager.new(session:)
        benchmarker = Benchmarker.new(session:)
        Runners.create(suite: load_suite!, session:).run do |group|
          Jobs::IPS.new(session:, group:, report_name:, test_name:, benchmarker:, results_manager:)
        end
      end
    end
  end
end
