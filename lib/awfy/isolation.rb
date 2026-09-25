# frozen_string_literal: true

module Awfy
  # How each measured call is isolated. :snapshot is recorded only: the caller
  # restores the snapshot before each run. awfy/rails registers :transaction.
  module Isolation
    NAMES = %i[transaction none snapshot].freeze

    module None
      def self.available? = true

      def self.wrap = yield
    end

    class << self
      def strategies
        @strategies ||= {none: None, snapshot: None}
      end

      def register(name, strategy)
        strategies[name] = strategy
      end

      def resolve(name)
        name ||= default_name
        strategy = strategies.fetch(name) do
          raise Errors::IsolationUnavailableError,
            "isolate #{name.inspect} is not available: :transaction needs `require \"awfy/rails\"` and an Active Record connection"
        end
        [name, strategy]
      end

      private

      def default_name
        transaction = strategies[:transaction]
        transaction&.available? ? :transaction : :none
      end
    end
  end
end
