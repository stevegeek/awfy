# frozen_string_literal: true

module Awfy
  module RetentionPolicies
    def create(policy_name, options = {})
      case policy_name
      when "none", "keep_none"
        KeepNone.new(options)
      when "date", "date_based"
        DateBased.new(options)
      else
        # Default to keep_all if an unknown policy is specified
        KeepAll.new(options)
      end
    end

    def none
      create("none")
    end
    alias_method :keep_none, :none

    def keep
      create("keep_all")
    end
    alias_method :keep_all, :keep

    def date_based
      create("date_based")
    end
    alias_method :date, :date_based

    module_function :create, :keep_none, :none, :keep, :keep_all, :date_based, :date
  end
end
