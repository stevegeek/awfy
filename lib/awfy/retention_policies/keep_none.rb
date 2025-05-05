# frozen_string_literal: true

require_relative "base"

module Awfy
  module RetentionPolicies
    # A retention policy that keeps no benchmark results.
    class KeepNone < Base
      def retain?(_result)
        false
      end
    end
  end
end
