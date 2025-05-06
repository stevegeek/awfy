# frozen_string_literal: true

module Awfy
  module RetentionPolicies
    def create(policy_name, ...)
      case PolicyAliases[policy_name]
      when PolicyAliases::None, PolicyAliases::KeepNone
        none(...)
      when PolicyAliases::Date, PolicyAliases::DateBased
        date_based(...)
      else
        keep(...)
      end
    end

    def none(...)
      KeepNone.new(...)
    end
    alias_method :keep_none, :none

    def keep(...)
      KeepAll.new(...)
    end
    alias_method :keep_all, :keep

    def date_based(...)
      DateBased.new(...)
    end
    alias_method :date, :date_based

    module_function :create, :keep_none, :none, :keep, :keep_all, :date_based, :date
  end
end
