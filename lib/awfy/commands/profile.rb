# frozen_string_literal: true

module Awfy
  module Commands
    class Profile < Base
      def run
        results_manager = Awfy::ResultsManager.new(session:)
        benchmarker = Benchmarker.new(session:)
        # Profile always uses immediate runner
        Runners.immediate(suite: load_suite!, session:).run do |group|
          Jobs::Profiling.new(session:, group:, report_name:, test_name:, benchmarker:, results_manager:)
        end
      end
    end
  end
end
