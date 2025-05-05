# frozen_string_literal: true

module Awfy
  module RetentionPolicy
    # Factory class for creating retention policy instances
    #
    # This class provides the create method that returns the appropriate
    # policy instance based on the provided options.
    class Factory
      def self.create(options)
        policy_name = options.retention_policy&.to_s&.downcase || "keep"

        case policy_name
        when "date"
          DateBased.new(options)
        else
          # Default to keep_all if an unknown policy is specified
          KeepAll.new(options)
        end
      end
    end
  end
end
