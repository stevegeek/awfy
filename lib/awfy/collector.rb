# frozen_string_literal: true

module Awfy
  # Measures one call. The pass runner creates a fresh instance per call and calls:
  #   #around (outermost first, each must return the value of its yield)
  #   #start (highest .order first), the test block,
  #   then, after every #around returned, #stop (lowest .order first).
  # #stop returns a JSON-friendly Hash with string keys, stored at
  # result_data["collectors"][key].
  class Collector
    class << self
      def key = raise(NotImplementedError, "#{name} must define .key")

      # Heavy collectors get a pass of their own.
      def heavy? = false

      # Start in descending order, stop in ascending order.
      def order = 0

      # The numeric values that compare and the run table show.
      def metrics(data) = data.select { |_, value| value.is_a?(Numeric) }

      def compare(base, other)
        base_metrics = metrics(base)
        other_metrics = metrics(other)
        (base_metrics.keys | other_metrics.keys).to_h do |name|
          [name, delta_row(base_metrics.fetch(name, 0), other_metrics.fetch(name, 0))]
        end
      end

      # Collector-specific lists for compare output: {title => [row Hash, ...]}.
      def extras(_base, _other) = {}

      def delta_row(base, other)
        unless base.is_a?(Numeric) && other.is_a?(Numeric)
          return {"base" => base, "other" => other, "delta" => nil, "pct" => nil}
        end

        delta = other - base
        {
          "base" => base,
          "other" => other,
          "delta" => delta.is_a?(Float) ? delta.round(6) : delta,
          "pct" => base.zero? ? nil : (delta * 100.0 / base).round(1)
        }
      end
    end

    def around(_context) = yield

    def start(_context) = nil

    def stop(_context) = {}
  end
end
