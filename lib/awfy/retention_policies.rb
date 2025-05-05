# frozen_string_literal: true

module Awfy
  module RetentionPolicies
    def create(policy_name, options = {})
      case policy_name
      when "none", "keep_none"
        none(options)
      when "date", "date_based"
        date_based(options)
      else
        # Default to keep_all if an unknown policy is specified
        keep(options)
      end
    end

    def none(options = {})
      KeepNone.new(options)
    end
    alias_method :keep_none, :none

    def keep(options = {})
      KeepAll.new(options)
    end
    alias_method :keep_all, :keep

    def date_based(options = {})
      DateBased.new(options)
    end
    alias_method :date, :date_based

    module_function :create, :keep_none, :none, :keep, :keep_all, :date_based, :date
  end
end
