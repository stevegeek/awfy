# frozen_string_literal: true

require "test_helper"

module Awfy
  module Suites
    class TestAssertion < Minitest::Test
      COLLECTED = {
        "sql" => {"queries" => 7},
        "timing" => {"wall_s" => 0.25},
        "memory_profiler" => {"allocated_memsize" => 2048, "allocated_by_gem" => [{"name" => "x"}]}
      }.freeze

      def failure(metric, bound) = Assertion.build(metric, bound).failure(COLLECTED)

      def test_build_accepts_symbol_keys_and_stores_the_path_as_a_string
        assert_equal "sql.queries", Assertion.build(:"sql.queries", 5).metric
      end

      def test_build_rejects_a_metric_without_a_collector
        error = assert_raises(ArgumentError) { Assertion.build("queries", 5) }
        assert_match(/"<collector>\.<metric>"/, error.message)
      end

      def test_build_rejects_a_bound_that_is_not_a_number_or_a_range
        error = assert_raises(ArgumentError) { Assertion.build("sql.queries", "5") }
        assert_match(/sql\.queries.*a number \(maximum\) or a Range/, error.message)
        assert_raises(ArgumentError) { Assertion.build("sql.queries", "a".."z") }
        assert_raises(ArgumentError) { Assertion.build("sql.queries", nil..nil) }
      end

      def test_an_integer_is_an_inclusive_maximum
        assert_nil failure("sql.queries", 7)
        assert_equal "sql.queries is 7, above the maximum 6", failure("sql.queries", 6)
      end

      def test_a_float_maximum
        assert_nil failure("timing.wall_s", 0.5)
        assert_equal "timing.wall_s is 0.25, above the maximum 0.1", failure("timing.wall_s", 0.1)
      end

      def test_a_range_bound
        assert_nil failure("sql.queries", ..7)
        assert_nil failure("sql.queries", 5..)
        assert_equal "sql.queries is 7, outside ...7", failure("sql.queries", ...7)
        assert_equal "sql.queries is 7, outside 8..10", failure("sql.queries", 8..10)
      end

      def test_a_collector_that_did_not_run_is_a_failure
        assert_equal "gc.minor_count cannot be checked: the 'gc' collector did not run " \
          "(add it with --collectors)", failure("gc.minor_count", 1)
      end

      def test_a_missing_metric_is_a_failure
        assert_equal "sql.writes cannot be checked: the 'sql' collector has no 'writes' value",
          failure("sql.writes", 1)
      end

      def test_a_value_that_is_not_a_number_is_a_failure
        assert_equal "memory_profiler.allocated_by_gem cannot be checked: its value is an Array, not a number",
          failure("memory_profiler.allocated_by_gem", 1)
      end

      def test_a_path_can_go_deeper_than_one_level
        collected = {"sidekiq" => {"jobs" => {"enqueued" => 3}}}
        assert_nil Assertion.build("sidekiq.jobs.enqueued", 3).failure(collected)
        assert_equal "sidekiq.jobs.enqueued is 3, above the maximum 2",
          Assertion.build("sidekiq.jobs.enqueued", 2).failure(collected)
      end
    end
  end
end
