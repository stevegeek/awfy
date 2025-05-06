# frozen_string_literal: true

module Awfy
  class StoreAliases < Literal::Enum(String)
    JSON = new("json")
    SQLite = new("sqlite")
    Memory = new("memory")
  end
end
