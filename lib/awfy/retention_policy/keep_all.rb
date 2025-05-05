# frozen_string_literal: true

require_relative "base"

module Awfy
  module RetentionPolicy
    # A retention policy that keeps all benchmark results.
    #
    # This policy is the default and will never clean up any results.
    # Use it when you want to preserve all historical benchmark data.
    class KeepAll < Base
      def retain?(_result)
        true
      end
    end
  end
end
