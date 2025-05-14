# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/comparison_formatters"
require "bigdecimal"

class TestComparisonFormatters < Minitest::Test
  # Test class that includes the ComparisonFormatters module
  class TestFormatter
    include Awfy::Views::ComparisonFormatters
  end

  def setup
    @formatter = TestFormatter.new
  end

  def test_to_big_decimal
    # Test conversion of various numeric types to BigDecimal
    assert_instance_of BigDecimal, @formatter.to_big_decimal(1)
    assert_instance_of BigDecimal, @formatter.to_big_decimal(1.5)
    assert_instance_of BigDecimal, @formatter.to_big_decimal("1.5")
    assert_instance_of BigDecimal, @formatter.to_big_decimal(BigDecimal("1.5"))

    # Test precision
    assert_equal BigDecimal("1.5"), @formatter.to_big_decimal(1.5)
    assert_equal BigDecimal("1.5"), @formatter.to_big_decimal("1.5")
  end

  def test_format_change
    # Test formatting of percentages
    assert_equal "+50.0%", @formatter.format_change(1.5)
    assert_equal "-50.0%", @formatter.format_change(0.5)
    assert_equal "No change", @formatter.format_change(1.0)

    # Test with small differences
    assert_equal "+1.0%", @formatter.format_change(1.01)
    assert_equal "-1.0%", @formatter.format_change(0.99)

    # Test with BigDecimal input
    assert_equal "+50.0%", @formatter.format_change(BigDecimal("1.5"))
    assert_equal "-50.0%", @formatter.format_change(BigDecimal("0.5"))
    assert_equal "No change", @formatter.format_change(BigDecimal("1.0"))
  end

  def test_format_comparison
    # Higher is better (default)
    assert_equal "2.0x faster", @formatter.format_comparison(2.0)
    assert_equal "2.0x slower", @formatter.format_comparison(0.5)
    assert_equal "baseline", @formatter.format_comparison(1.0)

    # Lower is better
    assert_equal "2.0x better", @formatter.format_comparison(0.5, false)
    assert_equal "2.0x worse", @formatter.format_comparison(2.0, false)
    assert_equal "baseline", @formatter.format_comparison(1.0, false)

    # Custom precision
    assert_equal "2.0x faster", @formatter.format_comparison(2.0, true, 2)
    assert_equal "2.0x faster", @formatter.format_comparison(2.0, true, 3)

    # With BigDecimal input
    assert_equal "2.0x faster", @formatter.format_comparison(BigDecimal("2.0"))
    assert_equal "2.0x slower", @formatter.format_comparison(BigDecimal("0.5"))
  end

  def test_format_result_diff
    # Test baseline result
    baseline_result = {is_baseline: true}
    assert_equal "-", @formatter.format_result_diff(baseline_result)

    # Test overlapping results
    overlap_result = {is_baseline: false, overlaps: true, diff_times: 1.5}
    assert_equal "same", @formatter.format_result_diff(overlap_result)

    # Test zero difference
    zero_result = {is_baseline: false, overlaps: false, diff_times: 0}
    assert_equal "same", @formatter.format_result_diff(zero_result)

    # Test infinity
    infinity_result = {is_baseline: false, overlaps: false, diff_times: Float::INFINITY}
    assert_equal "∞", @formatter.format_result_diff(infinity_result)

    # Test normal difference
    normal_result = {is_baseline: false, overlaps: false, diff_times: 1.5}
    assert_equal "1.5 x", @formatter.format_result_diff(normal_result)

    # Test missing diff
    missing_result = {is_baseline: false, overlaps: false}
    assert_equal "?", @formatter.format_result_diff(missing_result)
  end

  def test_format_memory_diff
    # Test baseline result
    baseline_result = {is_baseline: true}
    assert_equal "-", @formatter.format_memory_diff(baseline_result)

    # Test missing memory diff
    missing_result = {is_baseline: false, memory_diff: nil}
    assert_equal "N/A", @formatter.format_memory_diff(missing_result)

    # Test no change
    same_result = {is_baseline: false, memory_diff: 1.0}
    assert_equal "same", @formatter.format_memory_diff(same_result)

    # Test improvement
    better_result = {is_baseline: false, memory_diff: 0.8}
    assert_equal "20.0% better", @formatter.format_memory_diff(better_result)

    # Test regression
    worse_result = {is_baseline: false, memory_diff: 1.2}
    assert_equal "20.0% worse", @formatter.format_memory_diff(worse_result)
  end

  def test_humanize_scale
    # Test zero
    assert_equal "0", @formatter.humanize_scale(0)

    # Test small numbers
    assert_equal "500", @formatter.humanize_scale(500)

    # Test thousands
    assert_equal "1.5k", @formatter.humanize_scale(1500)

    # Test millions
    assert_equal "2.5M", @formatter.humanize_scale(2_500_000)

    # Test billions
    assert_equal "3.5B", @formatter.humanize_scale(3_500_000_000)

    # Test custom rounding
    assert_equal "1.0k", @formatter.humanize_scale(1234, round_to: -3)
    assert_equal "1.2k", @formatter.humanize_scale(1234, round_to: 1)
  end
end
