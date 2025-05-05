# frozen_string_literal: true

module Awfy
  module Stores
    @@instances = {}

    def create(backend = DEFAULT_BACKEND, options = nil, retention_policy = nil)
      backend = backend&.to_sym

      instance = case backend
      when :json
        Json.new(options, retention_policy)
      when :sqlite
        # Check if SQLite is available directly without instantiating
        begin
          require "sqlite3"
          Sqlite.new(options, retention_policy)
        rescue LoadError
          raise "SQLite backend requested but sqlite3 gem is not available. " \
                  "Please install it with: gem install sqlite3"
        end
      when :memory
        Memory.new(options, retention_policy)
      else
        raise "Unsupported backend: #{backend}"
      end

      # Store the instance for later retrieval
      @@instances[backend] = instance

      instance
    end

    def instance(backend = DEFAULT_BACKEND)
      backend = backend&.to_sym

      # Return existing instance if available and retention policy matches
      @@instances[backend] || raise("No backend for #{backend} has been created")
    end

    def reset!
      @@instances = {}
    end

    module_function :create, :instance, :reset!
  end
end
