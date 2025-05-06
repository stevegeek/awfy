# frozen_string_literal: true

module Awfy
  module Stores
    def create(backend, storage_name, retention_policy)
      case StoreAliases[backend]
      when StoreAliases::JSON
        json(storage_name, retention_policy)
      when StoreAliases::SQLite
        sqlite(storage_name, retention_policy)
      when StoreAliases::Memory
        memory(storage_name, retention_policy)
      else
        raise "Unsupported backend: #{backend}"
      end
    end

    def json(storage_name, retention_policy)
      require "json"
      Json.new(storage_name, retention_policy)
    end

    def sqlite(storage_name, retention_policy)
      require "sqlite3"
      Sqlite.new(storage_name, retention_policy)
    rescue LoadError
      raise "SQLite backend requested but sqlite3 gem is not available. " \
              "Please install it with: gem install sqlite3"
    end

    def memory(storage_name, retention_policy)
      Memory.new(storage_name, retention_policy)
    end

    module_function :create, :json, :sqlite, :memory
  end
end
