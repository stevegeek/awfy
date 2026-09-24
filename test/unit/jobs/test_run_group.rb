# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Jobs
    class TestRunGroupJob < Minitest::Test
      include JobTestHelpers

      def setup
        @config = create_test_config
        @session = create_test_session(@config)
        @group = create_test_group
        @benchmarker = Benchmarker.new(session: @session)
        @results_manager = ResultsManager.new(session: @session)
      end

      def test_initialize
        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        assert_instance_of RunGroup, job
      end

      def test_inherits_from_base
        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        assert_kind_of Base, job
      end

      def test_call_executes_test_blocks
        execution_count = 0
        test_block = proc { execution_count += 1 }

        test = Suites::Test.new(name: "counting_test", block: test_block)
        report = Suites::Report.new(name: "test_report", tests: [test])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        # The block should have been executed at least once (for lazy loading + iterations)
        assert execution_count >= 1, "Test block should be executed"
      end

      def test_call_with_specific_report
        test1_called = false
        test2_called = false

        test1 = Suites::Test.new(name: "test1", block: proc { test1_called = true })
        test2 = Suites::Test.new(name: "test2", block: proc { test2_called = true })

        report1 = Suites::Report.new(name: "report1", tests: [test1])
        report2 = Suites::Report.new(name: "report2", tests: [test2])

        group = Suites::Group.new(name: "test_group", reports: [report1, report2])

        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: "report1",
          test_name: nil
        )

        job.call

        assert test1_called, "Test1 should be called"
        refute test2_called, "Test2 should not be called"
      end

      def test_call_with_specific_test
        test1_called = false
        test2_called = false

        test1 = Suites::Test.new(name: "test1", block: proc { test1_called = true })
        test2 = Suites::Test.new(name: "test2", block: proc { test2_called = true })

        report = Suites::Report.new(name: "test_report", tests: [test1, test2])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: "test1"
        )

        job.call

        assert test1_called, "Test1 should be called"
        refute test2_called, "Test2 should not be called"
      end

      def test_call_runs_control_tests
        control_called = false

        control_test = Suites::ControlTest.new(
          name: "control",
          block: proc { control_called = true }
        )
        regular_test = Suites::Test.new(
          name: "regular",
          block: proc {}
        )

        report = Suites::Report.new(name: "test_report", tests: [control_test, regular_test])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = RunGroup.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        assert control_called, "Control test should be called"
      end
    end
  end
end
