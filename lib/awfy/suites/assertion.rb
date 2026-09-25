# frozen_string_literal: true

module Awfy
  module Suites
    # One performance assertion of a group or report: a "<collector>.<metric>" path into the
    # data a collector stored for a test, and a bound for its value. A number bound is an
    # inclusive maximum; a Range bound must cover the value.
    class Assertion < Literal::Data
      METRIC_FORMAT = /\A[^.]+(\.[^.]+)+\z/

      prop :metric, String
      prop :bound, _Union(Numeric, Range)

      def self.build(metric, bound)
        metric = metric.to_s
        unless METRIC_FORMAT.match?(metric)
          raise ArgumentError, "assert keys must be \"<collector>.<metric>\" paths, got #{metric.inspect}"
        end
        unless valid_bound?(bound)
          raise ArgumentError, "assert bound for #{metric} must be a number (maximum) or a Range of numbers, got #{bound.inspect}"
        end
        new(metric:, bound:)
      end

      def self.valid_bound?(bound)
        return true if bound.is_a?(Numeric)
        return false unless bound.is_a?(Range)
        ends = [bound.begin, bound.end].compact
        ends.any? && ends.all?(Numeric)
      end
      private_class_method :valid_bound?

      # The failure message for the collected data of one test, or nil if the assertion holds.
      # `collected` maps each collector key that ran to its stored data.
      def failure(collected)
        collector, *path = metric.split(".")
        data = collected[collector]
        return "#{metric} cannot be checked: the '#{collector}' collector did not run (add it with --collectors)" if data.nil?

        value = path.reduce(data) { |node, key| node.is_a?(Hash) ? node[key] : nil }
        return "#{metric} cannot be checked: the '#{collector}' collector has no '#{path.join(".")}' value" if value.nil?
        return "#{metric} cannot be checked: its value is #{article(value)} #{value.class}, not a number" unless value.is_a?(Numeric)

        if bound.is_a?(Range)
          "#{metric} is #{value}, outside #{bound}" unless bound.cover?(value)
        elsif value > bound
          "#{metric} is #{value}, above the maximum #{bound}"
        end
      end

      private

      def article(value) = value.class.name.match?(/\A[AEIOU]/) ? "an" : "a"
    end
  end
end
