# frozen_string_literal: true

module Awfy
  module Stores
    @@instances = {}

    def create(backend = DEFAULT_BACKEND, options = nil, retention_policy = nil)
      backend = backend&.to_sym

      instance = case backend
      when :json
        json(options, retention_policy)
      when :sqlite
        sqlite(options, retention_policy)
      when :memory
        memory(options, retention_policy)
      else
        raise "Unsupported backend: #{backend}"
      end

      # Store the instance for later retrieval
      @@instances[backend] = instance

      instance
    end

    def json(options = nil, retention_policy = nil)
      Json.new(options, retention_policy)
    end

    def sqlite(options = nil, retention_policy = nil)
      # Check if SQLite is available directly without instantiating

      require "sqlite3"
      Sqlite.new(options, retention_policy)
    rescue LoadError
      raise "SQLite backend requested but sqlite3 gem is not available. " \
              "Please install it with: gem install sqlite3"
    end

    def memory(options = nil, retention_policy = nil)
      Memory.new(options, retention_policy)
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
