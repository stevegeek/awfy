# frozen_string_literal: true

module Awfy
  class RetentionPolicyAliases < Literal::Enum(String)
    None = new("none")
    KeepNone = new("keep_none")
    Keep = new("keep")
    KeepAll = new("keep_all")
    Date = new("date")
    DateBased = new("date_based")

    def to_s
      value
    end
  end
end
