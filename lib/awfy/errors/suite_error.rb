# frozen_string_literal: true

module Awfy
  module Errors
    class SuiteError < StandardError
      def initialize(message = nil)
        super
      end
    end
  end
end
