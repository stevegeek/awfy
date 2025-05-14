# frozen_string_literal: true

module Awfy
  module RetentionPolicies
    # A retention policy that keeps benchmark results based on their age.
    #
    # Results newer than the cutoff date (defined by retention_days) are kept,
    # while older results are cleaned up. The default is to keep results from
    # the last 30 days.
    class DateBased < Base
      # @return [Integer] Number of days to retain results
      prop :retention_days, Integer, default: 30, reader: :public

      def retain?(result)
        cutoff_time = Time.now - @retention_days * 24 * 60 * 60
        result.timestamp >= cutoff_time
      end

      def name
        "#{super}_#{retention_days}_days"
      end
    end
  end
end
