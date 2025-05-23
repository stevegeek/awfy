# frozen_string_literal: true

require_relative "base"

module Awfy
  module RetentionPolicies
    # A retention policy that keeps all benchmark results.
    #
    # This policy is the default and will never clean up any results.
    class KeepAll < Base
      def retain?(_result)
        true
      end
    end
  end
end
