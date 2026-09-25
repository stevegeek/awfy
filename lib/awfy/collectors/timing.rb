# frozen_string_literal: true

module Awfy
  module Collectors
    class Timing < Collector
      def self.key = "timing"

      def self.order = -100

      def start(_context)
        @cpu = cpu_now
        @wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def stop(_context)
        wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @wall
        {"wall_s" => wall.round(6), "cpu_s" => (cpu_now - @cpu).round(6)}
      end

      private

      def cpu_now = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    end
  end
end
