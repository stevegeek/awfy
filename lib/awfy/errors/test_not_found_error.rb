# frozen_string_literal: true

require_relative "suite_error"

module Awfy
  module Errors
    class TestNotFoundError < SuiteError
      def initialize(group_name, report_name, test_name)
        super("Suite test with name '#{report_name}' not found in report '#{report_name}' and group '#{group_name}'.")
      end
    end
  end
end
