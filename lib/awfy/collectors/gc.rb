# frozen_string_literal: true

module Awfy
  module Collectors
    class Gc < Collector
      COUNTERS = %i[total_allocated_objects total_freed_objects count major_gc_count minor_gc_count].freeze

      def self.key = "gc"

      def self.order = -50

      def start(_context)
        @before = ::GC.stat.slice(*COUNTERS)
      end

      # Counter deltas, plus malloc_increase_bytes as it stands at stop (it is a gauge).
      def stop(_context)
        after = ::GC.stat
        COUNTERS.to_h { [it.to_s, after[it] - @before[it]] }
          .merge("malloc_increase_bytes" => after[:malloc_increase_bytes])
      end
    end
  end
end
