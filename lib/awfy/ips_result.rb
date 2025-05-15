# frozen_string_literal: true

require "uri"
require "securerandom"

module Awfy
  # Data object for benchmark result metadata
  class IPSResult < Result
    def central_tendency
      stats.central_tendency
    end

    def stats
      Benchmark::IPS::Stats::SD.new(result_data[:samples])
    end
  end
end
