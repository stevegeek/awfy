# frozen_string_literal: true

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
