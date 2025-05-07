# frozen_string_literal: true

module Awfy
  class StoreAliases < Literal::Enum(String)
    JSON = new("json")
    SQLite = new("sqlite")
    Memory = new("memory")

    def to_s
      value
    end
  end
end
