# frozen_string_literal: true

module Awfy
  module Commands
    class YJITStats < Base
      def run
        results_manager = Awfy::ResultsManager.new(session:)
        benchmarker = Benchmarker.new(session:)
        # YJIT stats always uses immediate runner
        Runners.immediate(suite: load_suite!, session:).run do |group|
          Jobs::YJITStats.new(session:, group:, report_name:, test_name:, benchmarker:, results_manager:)
        end
      end
    end
  end
end
