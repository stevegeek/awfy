# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Jobs
    class TestIPSJob < Minitest::Test
      include JobTestHelpers

      def setup
        @config = Config.new(
          verbose: VerbosityLevel::MUTE,
          runtime: "mri",
          test_time: 0.01,
          test_warm_up: 0.005,
          color: ColorMode::OFF,
          summary: false,
          storage_backend: "memory"
        )
        @session = create_test_session(@config)
        @benchmarker = Benchmarker.new(session: @session)
        @results_manager = ResultsManager.new(session: @session)
      end

      def test_initialize
        group = create_test_group

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        assert_instance_of IPS, job
      end

      def test_inherits_from_base
        group = create_test_group

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        assert_kind_of Base, job
      end

      def test_call_runs_benchmark_and_saves_results
        # Create a simple test group
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { 1 + 1 }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        # Run the job
        job.call

        # Verify results were saved
        results_found = false
        @results_manager.each_report(:ips) do |results, _baseline|
          results_found = true
          assert results.size >= 1
        end

        assert results_found, "Should have saved IPS results"
      end

      def test_call_with_multiple_tests
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { "a" * 10 }
        )
        alternative = Suites::Test.new(
          name: "alternative",
          block: proc { Array.new(10, "a").join }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline, alternative])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        # Verify multiple results were saved
        @results_manager.each_report(:ips) do |results, _baseline|
          assert_equal 2, results.size
        end
      end

      def test_call_with_control_test
        control = Suites::ControlTest.new(
          name: "control",
          block: proc { 1 }
        )
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { 2 }
        )
        report = Suites::Report.new(name: "test_report", tests: [control, baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        # Verify control test was saved
        control_found = false
        @results_manager.each_report(:ips) do |results, _baseline|
          control_found = results.any?(&:control?)
        end

        assert control_found, "Should have saved control test result"
      end

      def test_call_saves_git_info
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { 1 }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        # Verify git info was saved
        @results_manager.each_report(:ips) do |results, _baseline|
          result = results.first
          # Git info should be present (branch at minimum)
          refute_nil result.branch
        end
      end

      def test_call_with_specific_report
        baseline1 = Suites::BaselineTest.new(name: "b1", block: proc { 1 })
        baseline2 = Suites::BaselineTest.new(name: "b2", block: proc { 2 })
        report1 = Suites::Report.new(name: "report1", tests: [baseline1])
        report2 = Suites::Report.new(name: "report2", tests: [baseline2])
        group = Suites::Group.new(name: "test_group", reports: [report1, report2])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: "report1",
          test_name: nil
        )

        job.call

        # Verify only report1 results were saved
        @results_manager.each_report(:ips) do |results, _baseline|
          assert_equal 1, results.size
          assert_equal "report1", results.first.report_name
        end
      end

      def test_result_contains_benchmark_data
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { 1 + 1 }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = IPS.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        @results_manager.each_report(:ips) do |results, _baseline|
          result = results.first
          # IPS results should have result_data with benchmark metrics
          refute_nil result.result_data
          assert result.result_data.key?(:measured_us), "Should have measured_us"
          assert result.result_data.key?(:iter), "Should have iter"
          assert result.result_data.key?(:samples), "Should have samples"
          assert result.result_data[:iter] > 0, "Iterations should be positive"
        end
      end
    end
  end
end
