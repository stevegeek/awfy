# frozen_string_literal: true

require "test_helper"

module Awfy
  module Suites
    class TestTestClasses < Minitest::Test
      # Test class tests
      def test_test_initialize
        test = Test.new(name: "my_test", block: proc { 1 + 1 })

        assert_instance_of Test, test
        assert_equal "my_test", test.name
      end

      def test_test_control_returns_false
        test = Test.new(name: "test", block: proc {})

        refute test.control?
      end

      def test_test_baseline_returns_false
        test = Test.new(name: "test", block: proc {})

        refute test.baseline?
      end

      def test_test_block_is_callable
        result = nil
        test = Test.new(name: "test", block: proc { result = 42 })

        test.block.call

        assert_equal 42, result
      end

      # BaselineTest tests
      def test_baseline_test_initialize
        test = BaselineTest.new(name: "baseline", block: proc { "result" })

        assert_instance_of BaselineTest, test
      end

      def test_baseline_test_inherits_from_test
        test = BaselineTest.new(name: "baseline", block: proc {})

        assert_kind_of Test, test
      end

      def test_baseline_test_baseline_returns_true
        test = BaselineTest.new(name: "baseline", block: proc {})

        assert test.baseline?
      end

      def test_baseline_test_control_returns_false
        test = BaselineTest.new(name: "baseline", block: proc {})

        refute test.control?
      end

      # ControlTest tests
      def test_control_test_initialize
        test = ControlTest.new(name: "control", block: proc { nil })

        assert_instance_of ControlTest, test
      end

      def test_control_test_inherits_from_test
        test = ControlTest.new(name: "control", block: proc {})

        assert_kind_of Test, test
      end

      def test_control_test_control_returns_true
        test = ControlTest.new(name: "control", block: proc {})

        assert test.control?
      end

      def test_control_test_baseline_returns_false
        test = ControlTest.new(name: "control", block: proc {})

        refute test.baseline?
      end

      # Interaction between test types
      def test_different_test_types_are_distinct
        regular = Test.new(name: "regular", block: proc {})
        baseline = BaselineTest.new(name: "baseline", block: proc {})
        control = ControlTest.new(name: "control", block: proc {})

        refute regular.baseline?
        refute regular.control?

        assert baseline.baseline?
        refute baseline.control?

        refute control.baseline?
        assert control.control?
      end

      def test_test_types_can_be_collected
        tests = [
          Test.new(name: "regular", block: proc {}),
          BaselineTest.new(name: "baseline", block: proc {}),
          ControlTest.new(name: "control", block: proc {})
        ]

        assert_equal 3, tests.size
        assert_equal 1, tests.count(&:baseline?)
        assert_equal 1, tests.count(&:control?)
      end
    end
  end
end
