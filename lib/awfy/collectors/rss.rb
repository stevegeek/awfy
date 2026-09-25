# frozen_string_literal: true

module Awfy
  module Collectors
    # RSS before, after, and after 3x GC.start. Stops last (order 100): the forced GC would
    # distort the gc and timing collectors of the same pass.
    class Rss < Collector
      STATUS = "/proc/self/status"

      def self.key = "rss"

      def self.order = 100

      def self.current_mb
        if File.readable?(STATUS)
          kb = File.read(STATUS)[/^VmRSS:\s+(\d+)/, 1]
          return (kb.to_i / 1024.0).round(1) if kb
        end
        (`ps -o rss= -p #{Process.pid}`.to_i / 1024.0).round(1)
      end

      def start(_context)
        @before = self.class.current_mb
      end

      def stop(_context)
        after = self.class.current_mb
        3.times { ::GC.start }
        {"before_mb" => @before, "after_mb" => after, "after_gc_mb" => self.class.current_mb}
      end
    end
  end
end
