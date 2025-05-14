# frozen_string_literal: true

module Awfy
  module Commands
    class Flamegraph < Base
      def run
        results_manager = Awfy::ResultsManager.new(session:)
        benchmarker = Benchmarker.new(session:)
        # Flamegraph always uses immediate runner
        Runners.immediate(suite: load_suite!, session:).run do |group|
          Jobs::Flamegraph.new(session:, group:, report_name:, test_name:, benchmarker:, results_manager:)
        end
      end
    end
  end
end
