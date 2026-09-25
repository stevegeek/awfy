# frozen_string_literal: true

module Awfy
  module Errors
    class LabelNotFoundError < StandardError
      def initialize(label)
        super("No :measure results under label '#{label}' in this store")
      end
    end
  end
end
