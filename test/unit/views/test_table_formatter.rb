# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/table_formatter"

class TestTableFormatter < Minitest::Test
  # Test class that includes the TableFormatter module
  class TestFormatter
    include Awfy::Views::TableFormatter

    attr_accessor :options

    def initialize(options = nil)
      @options = options || MockOptions.new
    end
  end

  def setup
    @formatter = TestFormatter.new
  end

  def test_table_title
    # Test with all arguments
    assert_equal "Run: group/report/test", @formatter.table_title("group", "report", "test")

    # Test with group and report
    assert_equal "Run: group/report", @formatter.table_title("group", "report")

    # Test with just group
    assert_equal "Run: group", @formatter.table_title("group")

    # Test with empty arguments
    assert_equal "Run: (all)", @formatter.table_title(nil, nil, nil)
  end

  def test_order_description
    # Test default (non-memory) order descriptions
    @formatter.options = MockOptions.new(summary_order: "asc")
    assert_equal "Results displayed in ascending order", @formatter.order_description

    @formatter.options = MockOptions.new(summary_order: "desc")
    assert_equal "Results displayed in descending order", @formatter.order_description

    @formatter.options = MockOptions.new(summary_order: "leader")
    assert_equal "Results displayed as a leaderboard (best to worst)", @formatter.order_description

    # Test memory order descriptions
    @formatter.options = MockOptions.new(summary_order: "asc")
    assert_equal "Results displayed in ascending order (lowest memory first)", @formatter.order_description(true)

    @formatter.options = MockOptions.new(summary_order: "desc")
    assert_equal "Results displayed in descending order (highest memory first)", @formatter.order_description(true)

    @formatter.options = MockOptions.new(summary_order: "leader")
    assert_equal "Results displayed as a leaderboard (best to worst)", @formatter.order_description(true)
  end

  def test_sort_results
    # Create test data
    results = [
      {value: 10},
      {value: 30},
      {value: 20}
    ]

    # Extract the value for sorting
    value_extractor = ->(result) { result[:value] }

    # Test ascending order
    @formatter.options = MockOptions.new(summary_order: "asc")
    sorted = @formatter.sort_results(results, value_extractor)
    assert_equal [10, 20, 30], sorted.map { |r| r[:value] }

    # Test descending order
    @formatter.options = MockOptions.new(summary_order: "desc")
    sorted = @formatter.sort_results(results, value_extractor)
    assert_equal [30, 20, 10], sorted.map { |r| r[:value] }

    # Test with inversion (for "lower is better" metrics)
    @formatter.options = MockOptions.new(summary_order: "asc")
    sorted = @formatter.sort_results(results, value_extractor, true)
    assert_equal [30, 20, 10], sorted.map { |r| r[:value] }

    @formatter.options = MockOptions.new(summary_order: "desc")
    sorted = @formatter.sort_results(results, value_extractor, true)
    assert_equal [10, 20, 30], sorted.map { |r| r[:value] }
  end

  def test_has_runtime
    # Create test data
    results_by_commit = {
      "commit1" => {
        mri: [{"item" => "test1"}]
      },
      "commit2" => {
        yjit: [{"item" => "test1"}]
      }
    }

    # Test presence of runtimes
    assert_equal true, @formatter.has_runtime?(results_by_commit, :mri)
    assert_equal true, @formatter.has_runtime?(results_by_commit, :yjit)
    assert_equal false, @formatter.has_runtime?(results_by_commit, :truffleruby)
  end

  def test_find_test_result
    # Create test data
    results_by_commit = {
      "commit1" => {
        mri: [
          {"item" => "test1", "value" => 100},
          {"item" => "test2", "value" => 200}
        ]
      }
    }

    # Test finding specific test
    result = @formatter.find_test_result(results_by_commit, "commit1", :mri, "test2")
    assert_equal 200, result["value"]

    # Test non-existent test
    result = @formatter.find_test_result(results_by_commit, "commit1", :mri, "test3")
    assert_nil result

    # Test non-existent commit
    result = @formatter.find_test_result(results_by_commit, "commit2", :mri, "test1")
    assert_nil result

    # Test non-existent runtime
    result = @formatter.find_test_result(results_by_commit, "commit1", :yjit, "test1")
    assert_nil result
  end
end
