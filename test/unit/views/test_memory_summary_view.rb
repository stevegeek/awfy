# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/memory/summary_view"
require "bigdecimal"

class TestMemorySummaryView < ViewTestCase
  def setup
    super
    @view = Awfy::Views::Memory::SummaryView.new(session: @session)
  end

  def test_compute_result_diffs
    results, baseline = generate_memory_results(3)

    # Compute diffs
    result_diffs = @view.send(:compute_result_diffs, results, baseline)

    # Check that diffs were computed correctly
    assert_equal 3, result_diffs.size

    # First result should have memory_diff of 1.0 (baseline)
    assert_equal 1.0, result_diffs[0][:memory_diff]

    # Second result should have memory_diff of 2.0 (2x baseline)
    assert_equal 2.0, result_diffs[1][:memory_diff]

    # Third result should have memory_diff of 3.0 (3x baseline)
    assert_equal 3.0, result_diffs[2][:memory_diff]
  end

  def test_compute_result_diffs_with_zero_baseline
    # Create baseline with zero allocated memory
    baseline = {
      branch: "main",
      runtime: "mri",
      test_name: "Baseline",
      is_baseline: true,
      measurement: OpenStruct.new(
        allocated: 0,  # Zero allocated memory
        retained: 0,
        objects: OpenStruct.new(allocated: 0),
        strings: OpenStruct.new(allocated: 0)
      )
    }

    results = [baseline]

    # Add a non-baseline result
    results << {
      branch: "main",
      runtime: "yjit",
      test_name: "Test",
      is_baseline: false,
      measurement: OpenStruct.new(
        allocated: 1000,
        retained: 500,
        objects: OpenStruct.new(allocated: 100),
        strings: OpenStruct.new(allocated: 50)
      )
    }

    # Compute diffs
    result_diffs = @view.send(:compute_result_diffs, results, baseline)

    # Check that diffs were computed correctly
    assert_equal 2, result_diffs.size

    # First result should have memory_diff of nil (baseline with zero)
    assert_nil result_diffs[0][:memory_diff]

    # Second result should have memory_diff of nil (can't compute ratio with zero baseline)
    assert_nil result_diffs[1][:memory_diff]
  end

  def test_generate_table_rows
    results, baseline = generate_memory_results(3)
    result_diffs = @view.send(:compute_result_diffs, results, baseline)

    # Generate rows
    rows = @view.send(:generate_table_rows, result_diffs)

    # Check that rows were generated correctly
    assert_equal 3, rows.size

    # Check baseline row format
    baseline_row = rows[0]
    assert_equal 8, baseline_row.size  # 8 columns
    assert_equal "main", baseline_row[0]  # Branch
    assert_equal "mri", baseline_row[1]  # Runtime
    assert_equal "(baseline) Test 1", baseline_row[2]  # Name
    assert_equal "1.0M", baseline_row[3]  # Allocated Mem
    assert_equal "500.0k", baseline_row[4]  # Retained Mem
    assert_equal "10.0k", baseline_row[5]  # Objects
    assert_equal "5.0k", baseline_row[6]  # Strings
    assert_equal "-", baseline_row[7]  # Vs baseline

    # Check second row format
    second_row = rows[1]
    assert_equal 8, second_row.size
    assert_equal "main", second_row[0]
    assert_equal "yjit", second_row[1]
    assert_equal "Test 2", second_row[2]
    assert_equal "2.0M", second_row[3]
    assert_equal "1.0M", second_row[4]
    assert_equal "20.0k", second_row[5]
    assert_equal "10.0k", second_row[6]
    assert_equal "100.0% worse", second_row[7]  # 2x baseline = 100% worse
  end

  def test_format_memory_diff
    # Test baseline result
    baseline_result = {is_baseline: true}
    assert_equal "-", @view.send(:format_memory_diff, baseline_result)

    # Test missing memory diff
    missing_result = {is_baseline: false, memory_diff: nil}
    assert_equal "N/A", @view.send(:format_memory_diff, missing_result)

    # Test no change
    same_result = {is_baseline: false, memory_diff: 1.0}
    assert_equal "same", @view.send(:format_memory_diff, same_result)

    # Test improvement
    better_result = {is_baseline: false, memory_diff: 0.8}
    assert_equal "20.0% better", @view.send(:format_memory_diff, better_result)

    # Test regression
    worse_result = {is_baseline: false, memory_diff: 1.2}
    assert_equal "20.0% worse", @view.send(:format_memory_diff, worse_result)

    # Test with BigDecimal values
    bd_result = {is_baseline: false, memory_diff: BigDecimal("0.8")}
    assert_equal "20.0% better", @view.send(:format_memory_diff, bd_result)
  end

  def test_summary_table
    # Create test data
    report = [{"group" => "Test Group", "report" => "Memory Test"}]
    results, baseline = generate_memory_results(3)

    # Generate the summary table
    @view.summary_table(report, results, baseline)

    # Check that output was generated
    assert @shell.messages.any?

    # Find the terminal table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(Terminal::Table) }
    refute_nil table_output

    # Check that header contains expected title
    table_string = table_output[:message].to_s
    assert_includes table_string, "Run: Test Group/Memory Test"

    # Check that it contains expected headings
    assert_includes table_string, "Branch"
    assert_includes table_string, "Runtime"
    assert_includes table_string, "Name"
    assert_includes table_string, "Allocated Mem"
    assert_includes table_string, "Retained Mem"
    assert_includes table_string, "Objects"
    assert_includes table_string, "Strings"
    assert_includes table_string, "Vs baseline"

    # Check that sorting order description was output
    order_msg = @shell.messages.find do |m|
      next unless m[:message].is_a?(String)
      m[:message].include?("Results displayed in descending order (highest memory first)")
    end
    refute_nil order_msg

    # Test with quiet mode enabled
    @options.quiet = true
    @shell.messages.clear

    # Use a stringio to capture puts output
    original_stdout = $stdout
    $stdout = StringIO.new

    begin
      @view.summary_table(report, results, baseline)

      # Check that no messages were sent to the shell
      assert_empty @shell.messages

      # Check that table was printed via puts
      assert_includes $stdout.string, "Run: Test Group/Memory Test"
    ensure
      $stdout = original_stdout
    end
  end

  def test_summary_table_sorting
    # Create test data with varying memory usage
    report = [{"group" => "Test Group", "report" => "Memory Test"}]

    # Create 4 results with memory allocated in a non-sorted order: 3MB, 1MB, 4MB, 2MB
    results = []

    # Result 1: 3MB (3rd highest)
    results << {
      branch: "main",
      runtime: "mri",
      test_name: "Test 3MB",
      is_baseline: true,
      measurement: OpenStruct.new(
        allocated: 3_000_000,
        retained: 1_500_000,
        objects: OpenStruct.new(allocated: 30_000),
        strings: OpenStruct.new(allocated: 15_000)
      )
    }

    # Result 2: 1MB (lowest, should be first in output)
    results << {
      branch: "main",
      runtime: "yjit",
      test_name: "Test 1MB",
      is_baseline: false,
      measurement: OpenStruct.new(
        allocated: 1_000_000,
        retained: 500_000,
        objects: OpenStruct.new(allocated: 10_000),
        strings: OpenStruct.new(allocated: 5_000)
      )
    }

    # Result 3: 4MB (highest, should be last in output)
    results << {
      branch: "main",
      runtime: "mri",
      test_name: "Test 4MB",
      is_baseline: false,
      measurement: OpenStruct.new(
        allocated: 4_000_000,
        retained: 2_000_000,
        objects: OpenStruct.new(allocated: 40_000),
        strings: OpenStruct.new(allocated: 20_000)
      )
    }

    # Result 4: 2MB (2nd lowest)
    results << {
      branch: "main",
      runtime: "yjit",
      test_name: "Test 2MB",
      is_baseline: false,
      measurement: OpenStruct.new(
        allocated: 2_000_000,
        retained: 1_000_000,
        objects: OpenStruct.new(allocated: 20_000),
        strings: OpenStruct.new(allocated: 10_000)
      )
    }

    # Use first result as baseline
    baseline = results.first

    # Generate the summary table with descending order (default)
    @view.summary_table(report, results, baseline)

    # Find the terminal table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(Terminal::Table) }
    table_string = table_output[:message].to_s

    # Verify sorting order: For memory, lower is better, so the order should be:
    # 1MB, 2MB, 3MB (baseline), 4MB

    # Find the positions of each test in the table
    pos_1mb = table_string.index("Test 1MB")
    pos_2mb = table_string.index("Test 2MB")
    pos_3mb = table_string.index("(baseline) Test 3MB")
    pos_4mb = table_string.index("Test 4MB")

    # Check that they appear in the correct order
    assert pos_1mb < pos_2mb, "1MB should come before 2MB"
    assert pos_2mb < pos_3mb, "2MB should come before 3MB (baseline)"
    assert pos_3mb < pos_4mb, "3MB (baseline) should come before 4MB"

    # Now check with ascending order
    @shell.messages.clear
    @options.summary_order = "asc"

    @view.summary_table(report, results, baseline)

    # Find the terminal table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(Terminal::Table) }
    table_string = table_output[:message].to_s

    # For ascending order with memory (where lower is better), the order should be:
    # 4MB, 3MB (baseline), 2MB, 1MB

    # Find the positions of each test in the table
    pos_1mb = table_string.index("Test 1MB")
    pos_2mb = table_string.index("Test 2MB")
    pos_3mb = table_string.index("(baseline) Test 3MB")
    pos_4mb = table_string.index("Test 4MB")

    # Check that they appear in the correct order
    assert pos_4mb < pos_3mb, "4MB should come before 3MB (baseline)"
    assert pos_3mb < pos_2mb, "3MB (baseline) should come before 2MB"
    assert pos_2mb < pos_1mb, "2MB should come before 1MB"
  end
end
