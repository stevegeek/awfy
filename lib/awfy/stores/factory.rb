# frozen_string_literal: true

module Awfy
  module Stores
    class Factory
      @@instances = {}

      def self.instance(options = nil)
        # Use backend from options if not explicitly provided
        backend = options&.storage_backend&.to_sym || :json
        return @@instances[backend] if @@instances[backend]

        # Create a new instance based on backend type
        instance = case backend
        when :json
          Json.new(options)
        when :sqlite
          # Check if SQLite is available directly without instantiating
          begin
            require "sqlite3"
            Sqlite.new(options)
          rescue LoadError
            raise "SQLite backend requested but sqlite3 gem is not available. " \
                    "Please install it with: gem install sqlite3"
          end
        when :memory
          Memory.new(options)
        else
          raise "Unsupported backend: #{backend}"
        end

        # Store the instance for later retrieval
        @@instances[backend] = instance

        instance
      end

      # Reset the instance (useful for testing)
      def self.reset!
        @@instances = {}
      end
    end
  end
end
