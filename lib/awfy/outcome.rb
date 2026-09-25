# frozen_string_literal: true

require "json"

module Awfy
  # The observable result of a measured call, stored at result_data["outcome"].
  # A test block's return value that responds to #awfy_outcome wins; otherwise a helper may
  # record a value, or a block that receives the pass's collected data (perform_job uses the
  # sidekiq collector's enqueued summary that way).
  module Outcome
    KEY = :awfy_outcome

    class << self
      def record(value = nil, &block)
        Thread.current[KEY] = block || value
      end

      def reset!
        Thread.current[KEY] = nil
      end

      def resolve(return_value, collected)
        source = return_value.respond_to?(:awfy_outcome) ? return_value.awfy_outcome : Thread.current[KEY]
        source = source.call(collected) if source.respond_to?(:call)
        source.nil? ? nil : JSON.parse(JSON.generate(source))
      end
    end
  end
end
