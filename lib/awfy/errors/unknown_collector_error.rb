# frozen_string_literal: true

module Awfy
  module Errors
    class UnknownCollectorError < StandardError
      def initialize(key, known)
        super("Unknown collector '#{key}'. Known collectors: #{known.sort.join(", ")}. " \
          "The Rails collectors (sql, instantiation, cache, sidekiq) need `require \"awfy/rails\"` in the setup file.")
      end
    end
  end
end
