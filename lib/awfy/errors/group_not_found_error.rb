# frozen_string_literal: true

module Awfy
  module Errors
    class GroupNotFoundError < SuiteError
      def initialize(group_name)
        super("Suite group with name '#{group_name}' not found.")
      end
    end
  end
end
