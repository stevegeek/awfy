# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Jobs
    class TestMemoryJob < Minitest::Test
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

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        assert_instance_of Memory, job
      end

      def test_inherits_from_base
        group = create_test_group

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        assert_kind_of Base, job
      end

      def test_call_runs_memory_profile_and_saves_results
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { "a" * 100 }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        # Verify results were saved
        results_found = false
        @results_manager.each_report(:memory) do |results, _baseline|
          results_found = true
          assert results.size >= 1
        end

        assert results_found, "Should have saved memory results"
      end

      def test_call_with_multiple_tests
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { Array.new(100) { "x" } }
        )
        alternative = Suites::Test.new(
          name: "alternative",
          block: proc { (1..100).map(&:to_s) }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline, alternative])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        @results_manager.each_report(:memory) do |results, _baseline|
          assert_equal 2, results.size
        end
      end

      def test_call_with_control_test
        control = Suites::ControlTest.new(
          name: "control",
          block: proc { [] }
        )
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { [1, 2, 3] }
        )
        report = Suites::Report.new(name: "test_report", tests: [control, baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        control_found = false
        @results_manager.each_report(:memory) do |results, _baseline|
          control_found = results.any?(&:control?)
        end

        assert control_found, "Should have saved control test result"
      end

      def test_result_contains_memory_data
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { Array.new(100) { Object.new } }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        @results_manager.each_report(:memory) do |results, _baseline|
          result = results.first
          refute_nil result.result_data

          # Memory results should have these fields
          assert result.result_data.key?(:allocated_memsize), "Should have allocated_memsize"
          assert result.result_data.key?(:allocated_objects), "Should have allocated_objects"
          assert result.result_data.key?(:retained_memsize), "Should have retained_memsize"
          assert result.result_data.key?(:retained_objects), "Should have retained_objects"

          # Our test creates objects, so we should see allocations
          assert result.result_data[:allocated_objects] > 0, "Should have allocated objects"
        end
      end

      def test_call_with_specific_report
        baseline1 = Suites::BaselineTest.new(name: "b1", block: proc { [1] })
        baseline2 = Suites::BaselineTest.new(name: "b2", block: proc { [2] })
        report1 = Suites::Report.new(name: "report1", tests: [baseline1])
        report2 = Suites::Report.new(name: "report2", tests: [baseline2])
        group = Suites::Group.new(name: "test_group", reports: [report1, report2])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: "report1",
          test_name: nil
        )

        job.call

        @results_manager.each_report(:memory) do |results, _baseline|
          assert_equal 1, results.size
          assert_equal "report1", results.first.report_name
        end
      end

      def test_call_saves_git_info
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc { "test" }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        @results_manager.each_report(:memory) do |results, _baseline|
          result = results.first
          refute_nil result.branch
        end
      end

      def test_memory_profiling_captures_allocations
        # Create a test that allocates objects (use Object.new to avoid interning)
        baseline = Suites::BaselineTest.new(
          name: "baseline",
          block: proc {
            # Allocate distinct objects
            10.times.map { Object.new }
          }
        )
        report = Suites::Report.new(name: "test_report", tests: [baseline])
        group = Suites::Group.new(name: "test_group", reports: [report])

        job = Memory.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: group,
          report_name: nil,
          test_name: nil
        )

        job.call

        @results_manager.each_report(:memory) do |results, _baseline|
          result = results.first
          # Memory profiler should detect allocations
          assert result.result_data[:allocated_objects] > 0,
            "Should have allocated some objects, got #{result.result_data[:allocated_objects]}"
        end
      end
    end
  end
end
