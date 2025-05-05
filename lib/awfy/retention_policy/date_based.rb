# frozen_string_literal: true

require_relative "base"

module Awfy
  module RetentionPolicy
    # A retention policy that keeps benchmark results based on their age.
    #
    # Results newer than the cutoff date (defined by retention_days) are kept,
    # while older results are cleaned up. The default is to keep results from
    # the last 30 days.
    class DateBased < Base
      # @return [Integer] Number of days to retain results
      attr_reader :retention_days

      def initialize(options)
        super
        @retention_days = options.retention_days || 30
      end

      def retain?(result)
        return true unless result.respond_to?(:timestamp)

        cutoff_timestamp = (Time.now - retention_days * 24 * 60 * 60).to_i
        result.timestamp >= cutoff_timestamp
      end

      def name
        "date_based_#{retention_days}_days"
      end
    end
  end
end
