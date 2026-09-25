# frozen_string_literal: true

require "benchmark/ips"

module Awfy
  # Data object for benchmark result metadata
  class IPSResult < Result
    MICROSECONDS_PER_SECOND = 1_000_000.0

    # Builds benchmark-ips standard-deviation stats from stored result data.
    #
    # benchmark-ips 2.14 builds SD from the samples alone and takes their mean as the
    # central tendency. From 2.15 it also takes the total measured time and iteration
    # count, and the central tendency is iterations per second over the whole run.
    # Result data without that timing gets a time and count whose ratio is the mean of
    # the samples, so it reads the same under both versions.
    def self.stats_for(result_data, sd_class: ::Benchmark::IPS::Stats::SD)
      samples = result_data[:samples]
      return sd_class.new(samples) if sd_class.instance_method(:initialize).arity == 1

      measured_us = result_data[:measured_us]
      iterations = result_data[:iter]
      if measured_us.nil? || iterations.nil?
        measured_us = MICROSECONDS_PER_SECOND
        iterations = samples.sum.to_f / samples.size
      end
      sd_class.new(samples, measured_us, iterations)
    end

    def central_tendency
      stats.central_tendency
    end

    def stats
      self.class.stats_for(result_data)
    end
  end
end
