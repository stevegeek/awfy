# frozen_string_literal: true

require_relative "suite_error"

module Awfy
  module Errors
    class ReportNotFoundError < SuiteError
      def initialize(group_name, report_name)
        super("Suite group report with name '#{report_name}' not found in group '#{group_name}'.")
      end
    end
  end
end
