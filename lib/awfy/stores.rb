# frozen_string_literal: true

module Awfy
  module Stores
    @@instances = {}

    def create(backend = DEFAULT_BACKEND, storage_name = nil, retention_policy = nil)
      backend = backend&.to_sym

      instance = case backend
      when :json
        json(storage_name, retention_policy)
      when :sqlite
        sqlite(storage_name, retention_policy)
      when :memory
        memory(storage_name, retention_policy)
      else
        raise "Unsupported backend: #{backend}"
      end

      # Store the instance for later retrieval
      @@instances[backend] = instance

      instance
    end

    def json(storage_name = nil, retention_policy = nil)
      Json.new(storage_name, retention_policy)
    end

    def sqlite(storage_name = nil, retention_policy = nil)
      # Check if SQLite is available directly without instantiating

      require "sqlite3"
      Sqlite.new(storage_name, retention_policy)
    rescue LoadError
      raise "SQLite backend requested but sqlite3 gem is not available. " \
              "Please install it with: gem install sqlite3"
    end

    def memory(storage_name = nil, retention_policy = nil)
      Memory.new(storage_name, retention_policy)
    end

    def instance(backend = DEFAULT_BACKEND)
      backend = backend&.to_sym

      # Return existing instance if available and retention policy matches
      @@instances[backend] || raise("No backend for #{backend} has been created")
    end

    def reset!
      @@instances = {}
    end

    module_function :create, :json, :sqlite, :memory, :instance, :reset!
  end
end
