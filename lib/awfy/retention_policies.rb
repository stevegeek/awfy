# frozen_string_literal: true

module Awfy
  module RetentionPolicies
    def create(policy_name, ...)
      case RetentionPolicyAliases[policy_name.to_s]
      when RetentionPolicyAliases::None, RetentionPolicyAliases::KeepNone
        none
      when RetentionPolicyAliases::Date, RetentionPolicyAliases::DateBased
        date_based(...)
      when RetentionPolicyAliases::Keep, RetentionPolicyAliases::KeepAll
        keep
      else
        raise "Unknown retention policy: #{policy_name}"
      end
    end

    def none
      KeepNone.new
    end
    alias_method :keep_none, :none

    def keep
      KeepAll.new
    end
    alias_method :keep_all, :keep

    def date_based(...)
      DateBased.new(...)
    end
    alias_method :date, :date_based

    module_function :create, :keep_none, :none, :keep, :keep_all, :date_based, :date
  end
end
