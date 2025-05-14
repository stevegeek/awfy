# frozen_string_literal: true

module Awfy
  module Errors
    class GroupEmptyError < SuiteError
      def initialize(group_name)
        super("Suite group with name '#{group_name}' is empty.")
      end
    end
  end
end
