# frozen_string_literal: true

module Awfy
  module Errors
    class TestNotFoundError < SuiteError
      def initialize(group_name, report_name, test_name)
        super("Suite test with name '#{test_name}' not found in report '#{report_name}' and group '#{group_name}'.")
      end
    end
  end
end
