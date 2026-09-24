# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Jobs
    class TestBaseJob < Minitest::Test
      include JobTestHelpers

      def setup
        @config = create_test_config
        @session = create_test_session(@config)
        @group = create_test_group
        @benchmarker = Benchmarker.new(session: @session)
        @results_manager = ResultsManager.new(session: @session)
      end

      def test_call_raises_not_implemented_error
        job = Base.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        assert_raises(NoMethodError) do
          job.call
        end
      end

      def test_initialize_with_all_parameters
        job = Base.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: "test_report",
          test_name: "test1"
        )

        assert_instance_of Base, job
      end

      def test_initialize_with_nil_report_name
        job = Base.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        assert_instance_of Base, job
      end

      def test_generate_test_label_for_regular_test
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        test = Suites::Test.new(name: "my_test", block: proc {})
        label = job.test_generate_test_label(test, "mri")

        assert_equal "[mri] [*] my_test", label
      end

      def test_generate_test_label_for_control_test
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        test = Suites::ControlTest.new(name: "control", block: proc {})
        label = job.test_generate_test_label(test, "yjit")

        assert_equal "[yjit] [c] control", label
      end

      def test_generate_test_label_for_baseline_test
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        test = Suites::BaselineTest.new(name: "baseline", block: proc {})
        label = job.test_generate_test_label(test, "mri")

        assert_equal "[mri] [*][b] baseline", label
      end

      def test_marked_as_control
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        control_entry = MockEntry.new(label: "[mri] [c] control")
        test_entry = MockEntry.new(label: "[mri] [*] test")

        assert job.test_marked_as_control?(control_entry)
        refute job.test_marked_as_control?(test_entry)
      end

      def test_marked_as_test
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        test_entry = MockEntry.new(label: "[mri] [*] test")
        control_entry = MockEntry.new(label: "[mri] [c] control")

        assert job.test_marked_as_test?(test_entry)
        refute job.test_marked_as_test?(control_entry)
      end

      def test_marked_as_baseline
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        baseline_entry = MockEntry.new(label: "[mri] [*][b] baseline")
        non_baseline_entry = MockEntry.new(label: "[mri] [*] test")

        assert job.test_marked_as_baseline?(baseline_entry)
        refute job.test_marked_as_baseline?(non_baseline_entry)
      end

      def test_current_git_info_returns_hash
        job = TestableJob.new(
          session: @session,
          benchmarker: @benchmarker,
          results_manager: @results_manager,
          group: @group,
          report_name: nil,
          test_name: nil
        )

        git_info = job.test_current_git_info

        assert_kind_of Hash, git_info
        assert git_info.key?(:branch)
        assert git_info.key?(:commit_hash)
        assert git_info.key?(:commit_message)
      end

      def test_markers_are_constants
        assert_equal "[c]", Base::CONTROL_MARKER
        assert_equal "[*]", Base::TEST_MARKER
        assert_equal "[b]", Base::BASELINE_MARKER
      end
    end

    # Testable subclass that exposes private methods for testing
    class TestableJob < Base
      def call
        # Do nothing - just for testing
      end

      def test_generate_test_label(test, runtime)
        generate_test_label(test, runtime)
      end

      def test_marked_as_control?(entry)
        marked_as_control?(entry)
      end

      def test_marked_as_test?(entry)
        marked_as_test?(entry)
      end

      def test_marked_as_baseline?(entry)
        marked_as_baseline?(entry)
      end

      def test_current_git_info
        current_git_info
      end
    end

    # Mock entry for testing marker detection
    class MockEntry
      attr_reader :label

      def initialize(label:)
        @label = label
      end
    end
  end
end
