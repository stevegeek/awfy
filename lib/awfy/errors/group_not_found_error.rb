# frozen_string_literal: true

require_relative "suite_error"

module Awfy
  module Errors
    class GroupNotFoundError < SuiteError
      def initialize(group_name)
        super("Suite group with name '#{group_name}' not found.")
      end
    end
  end
end
