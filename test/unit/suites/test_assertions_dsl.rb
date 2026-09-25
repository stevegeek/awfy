# frozen_string_literal: true

require "test_helper"

class AssertionsDslTest < Minitest::Test
  def build(&block)
    suite = Awfy::Suite.new
    suite.group("G", &block)
    suite.groups.first
  end

  def bounds(assertions) = assertions.to_h { [it.metric, it.bound] }

  def test_group_and_report_level_assertions
    group = build do
      assert "sql.queries" => ..5
      report("R") do
        assert "memory_profiler.allocated_memsize" => 1_000_000, :"timing.wall_s" => 0.1..0.5
        test("t") {}
      end
    end
    assert_equal({"sql.queries" => ..5}, bounds(group.assertions))
    assert_equal({"memory_profiler.allocated_memsize" => 1_000_000, "timing.wall_s" => 0.1..0.5},
      bounds(group.reports.first.assertions))
  end

  def test_assertions_after_a_report_block_go_to_the_group
    group = build do
      report("R") { test("t") {} }
      assert "sql.queries" => 1
    end
    assert_equal ["sql.queries"], group.assertions.map(&:metric)
    assert_empty group.reports.first.assertions
  end

  def test_repeated_assert_calls_add_up
    group = build do
      assert "sql.queries" => 1
      assert "gc.major_count" => 0
    end
    assert_equal ["sql.queries", "gc.major_count"], group.assertions.map(&:metric)
  end

  def test_invalid_assertions_raise_when_the_suite_loads
    assert_raises(ArgumentError) { build { assert "queries" => 1 } }
    assert_raises(ArgumentError) { build { assert "sql.queries" => "1" } }
    assert_raises(ArgumentError) { build { assert 5 } }
  end

  def test_a_report_assertion_overrides_the_group_assertion_for_the_same_metric
    group = build do
      assert "sql.queries" => 5, "gc.major_count" => 0
      report("R") do
        assert "sql.queries" => 50
        test("t") {}
      end
    end
    report = group.reports.first
    assert_equal({"gc.major_count" => 0, "sql.queries" => 50}, bounds(report.assertions_within(group)))
  end
end
