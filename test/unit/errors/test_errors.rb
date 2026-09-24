# frozen_string_literal: true

require "test_helper"

module Awfy
  module Errors
    class TestErrors < Minitest::Test
      def test_suite_error_inherits_from_standard_error
        error = SuiteError.new("test message")
        assert_instance_of SuiteError, error
        assert_kind_of StandardError, error
      end

      def test_suite_error_with_message
        error = SuiteError.new("custom error message")
        assert_equal "custom error message", error.message
      end

      def test_suite_error_without_message
        error = SuiteError.new
        # SuiteError with no message returns the class name
        assert_match(/SuiteError/, error.message)
      end

      def test_suite_error_can_be_raised
        assert_raises(SuiteError) do
          raise SuiteError, "test error"
        end
      end

      def test_no_baseline_error_inherits_from_standard_error
        error = NoBaselineError.new("no baseline")
        assert_instance_of NoBaselineError, error
        assert_kind_of StandardError, error
      end

      def test_no_baseline_error_with_message
        error = NoBaselineError.new("No baseline found for comparison")
        assert_equal "No baseline found for comparison", error.message
      end

      def test_no_baseline_error_can_be_raised
        assert_raises(NoBaselineError) do
          raise NoBaselineError, "missing baseline"
        end
      end

      def test_suite_empty_error_inherits_from_standard_error
        error = SuiteEmptyError.new("suite is empty")
        assert_instance_of SuiteEmptyError, error
        assert_kind_of StandardError, error
      end

      def test_suite_empty_error_can_be_raised
        assert_raises(SuiteEmptyError) do
          raise SuiteEmptyError, "No tests in suite"
        end
      end

      def test_group_not_found_error_inherits_from_standard_error
        error = GroupNotFoundError.new("group not found")
        assert_instance_of GroupNotFoundError, error
        assert_kind_of StandardError, error
      end

      def test_group_not_found_error_can_be_raised
        assert_raises(GroupNotFoundError) do
          raise GroupNotFoundError, "Group 'test' not found"
        end
      end

      def test_report_not_found_error_inherits_from_standard_error
        error = ReportNotFoundError.new("group1", "report1")
        assert_instance_of ReportNotFoundError, error
        assert_kind_of StandardError, error
        assert_kind_of SuiteError, error
      end

      def test_report_not_found_error_formats_message
        error = ReportNotFoundError.new("TestGroup", "TestReport")
        assert_match(/TestReport/, error.message)
        assert_match(/TestGroup/, error.message)
      end

      def test_report_not_found_error_can_be_raised
        assert_raises(ReportNotFoundError) do
          raise ReportNotFoundError.new("group", "report")
        end
      end

      def test_test_not_found_error_inherits_from_standard_error
        error = TestNotFoundError.new("group1", "report1", "test1")
        assert_instance_of TestNotFoundError, error
        assert_kind_of StandardError, error
        assert_kind_of SuiteError, error
      end

      def test_test_not_found_error_formats_message
        error = TestNotFoundError.new("TestGroup", "TestReport", "TestCase")
        assert_match(/TestCase/, error.message)
        assert_match(/TestReport/, error.message)
        assert_match(/TestGroup/, error.message)
      end

      def test_test_not_found_error_can_be_raised
        assert_raises(TestNotFoundError) do
          raise TestNotFoundError.new("group", "report", "test")
        end
      end

      def test_group_empty_error_inherits_from_standard_error
        error = GroupEmptyError.new("group is empty")
        assert_instance_of GroupEmptyError, error
        assert_kind_of StandardError, error
      end

      def test_group_empty_error_can_be_raised
        assert_raises(GroupEmptyError) do
          raise GroupEmptyError, "No reports in group"
        end
      end

      def test_all_errors_are_distinct_classes
        errors = [
          SuiteError,
          NoBaselineError,
          SuiteEmptyError,
          GroupNotFoundError,
          ReportNotFoundError,
          TestNotFoundError,
          GroupEmptyError
        ]

        # Each error class should be unique
        assert_equal errors.uniq.size, errors.size
      end

      def test_errors_can_be_caught_specifically
        raise SuiteError, "specific error"
      rescue SuiteError => e
        assert_equal "specific error", e.message
      rescue
        flunk "Should have caught SuiteError specifically"
      end

      def test_errors_can_be_caught_as_standard_error
        raise NoBaselineError, "baseline missing"
      rescue => e
        assert_instance_of NoBaselineError, e
      end
    end
  end
end
