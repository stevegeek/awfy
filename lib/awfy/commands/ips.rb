# frozen_string_literal: true

module Awfy
  module Commands
    class IPS < Base
      prop :group, _Nilable(String)
      prop :report, _Nilable(String)
      prop :test, _Nilable(String)

      def run(report_name = nil, test_name = nil)
        results_manager = Awfy::ResultsManager.new(session:)
        Runners.create(suite: load_suite!, session:).run do |group|
          Jobs::IPS.new(session:, group:, report_name:, test_name:, benchmarker: Benchmarker.new(session:), results_manager:)
        end
      end
    end
  end
end
