# frozen_string_literal: true

require "json"

module Awfy
  # Resolves the collector keys given on the command line.
  module Collectors
    class << self
      def register(klass)
        registry[klass.key] = klass
      end

      def fetch(key)
        registry.fetch(key) { raise Errors::UnknownCollectorError.new(key, registry.keys) }
      end

      def lookup(key) = registry[key]

      def keys = registry.keys.sort

      # Stored, printed and compared data all have string keys and JSON types.
      def normalize(data) = JSON.parse(JSON.generate(data || {}))

      private

      # Built on first use so Zeitwerk loads each core collector lazily.
      def registry
        @registry ||= [Timing, Gc, Rss, MemoryProfiler, Vernier].to_h { [it.key, it] }
      end
    end
  end
end
