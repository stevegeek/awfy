# frozen_string_literal: true

require "memory_profiler"

module Awfy
  module Collectors
    # The data Jobs::Memory stores: totals, and the top 25 by gem/file/location/class for
    # allocated and retained memory and objects.
    class MemoryProfiler < Collector
      TOP = 25
      SITES = 15
      LISTS = %w[
        allocated_memory_by_gem allocated_memory_by_file allocated_memory_by_location allocated_memory_by_class
        retained_memory_by_gem retained_memory_by_file retained_memory_by_location retained_memory_by_class
        allocated_objects_by_gem allocated_objects_by_file allocated_objects_by_location allocated_objects_by_class
        retained_objects_by_gem retained_objects_by_file retained_objects_by_location retained_objects_by_class
      ].freeze

      def self.key = "memory_profiler"

      def self.heavy? = true

      def self.metrics(data) = data.slice("allocated_memsize", "allocated_objects", "retained_memsize", "retained_objects")

      # The baseline's top 15 allocation locations and their value under the other label.
      def self.extras(base, other)
        other_sites = other.fetch("allocated_memory_by_location", []).to_h { [it["data"], it["count"]] }
        sites = base.fetch("allocated_memory_by_location", []).first(SITES).map do |site|
          {"location" => site["data"], "baseline" => site["count"], "against" => other_sites[site["data"]]}
        end
        {"allocation_sites" => sites}
      end

      def around(_context)
        value = nil
        @report = ::MemoryProfiler.report(top: TOP) { value = yield }
        value
      end

      def stop(_context)
        report = @report
        return {} unless report # around never completed (a test error): nothing to report

        totals = {
          "allocated_memsize" => report.total_allocated_memsize,
          "allocated_objects" => report.total_allocated,
          "retained_memsize" => report.total_retained_memsize,
          "retained_objects" => report.total_retained,
          "allocated_strings" => Array(report.strings_allocated).size,
          "retained_strings" => Array(report.strings_retained).size
        }
        totals.merge(LISTS.to_h { |list| [list, rows(report.public_send(list))] })
      end

      private

      def rows(list) = Array(list).first(TOP).map { {"data" => it[:data], "count" => it[:count]} }
    end
  end
end
