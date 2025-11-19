# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/memory/summary_view"
require "awfy/views/memory/summary_table"
require "bigdecimal"

class TestMemorySummaryView < ViewTestCase
  def setup
    super
    @baseline = Awfy::Result.new(
      type: :memory,
      runtime: Awfy::Runtimes::MRI,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test1", # This will become the label if not overridden by result_data[:label]
      branch: "main",
      baseline: true,
      timestamp: Time.now,
      result_data: {
        label: "Baseline Test", # Explicitly setting label here
        allocated_memsize: 1_000_000,
        retained_memsize: 500_000,
        allocated_objects: 10_000,
        allocated_strings: 5_000
      }
    )

    @view = Awfy::Views::Memory::SummaryView.new(
      session: @session,
      group_name: "test_group",
      report_name: "test_report",
      test_name: nil, # test_name for the view, not for the result
      results: [@baseline],
      baseline: @baseline
    )
  end

  def test_render_with_single_result
    # Call render
    table = @view.render

    # Check that output was generated
    assert @shell.messages.any?

    refute_nil table, "Table should have been generated"
    assert_equal 1, table.rows.size, "Should have one row for the baseline result"

    baseline_row = table.rows.first
    assert_equal "(test) Baseline Test", baseline_row.columns[:test_name]

    # Check that sorting order description was output (from the rendered string)
    table_output_message = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output_message, "Expected table output string"
    assert_match(/Results displayed/, table_output_message[:message])
  end

  def test_render_with_multiple_results
    # Add a non-baseline result
    results_list = [@baseline]
    results_list << Awfy::Result.new(
      type: :memory,
      runtime: Awfy::Runtimes::YJIT,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test2",
      branch: "main",
      baseline: false,
      timestamp: Time.now,
      result_data: {
        label: "Test Result",
        allocated_memsize: 2_000_000,
        retained_memsize: 1_000_000,
        allocated_objects: 20_000,
        allocated_strings: 10_000
      }
    )

    # Create a view with multiple results
    view = Awfy::Views::Memory::SummaryView.new(
      session: @session,
      group_name: "test_group",
      report_name: "test_report",
      test_name: nil,
      results: results_list, # Use the local variable
      baseline: @baseline
    )

    # Call render
    table = view.render

    # Check that output was generated
    assert @shell.messages.any?

    refute_nil table, "Table should have been generated"
    assert_equal 2, table.rows.size, "Should have two rows"

    # Assuming descending sort order by default (highest memory first)
    # The "Test Result" (2MB) should be first, then "Baseline Test" (1MB)
    # However, the sorting also prioritizes non-baseline after baseline if memory is equal.
    # Let's find them by their known properties.

    baseline_row = table.rows.find { |r| r.columns[:test_name] == "(test) Baseline Test" }
    other_row = table.rows.find { |r| r.columns[:test_name] == "Test Result" }

    refute_nil baseline_row, "Baseline row not found"
    refute_nil other_row, "Other test row not found"

    assert_equal "(test) Baseline Test", baseline_row.columns[:test_name]
    assert_equal "Test Result", other_row.columns[:test_name]

    # Check that memory values are correct in the row data
    assert_equal 1_000_000, baseline_row.columns[:allocated_memory]
    assert_equal 2_000_000, other_row.columns[:allocated_memory]

    # Check that humanized values are present in the row data
    assert_equal "1.0M", baseline_row.columns[:humanized_allocated]
    assert_equal "2.0M", other_row.columns[:humanized_allocated]

    # Check that sorting order description was output
    table_output_message = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output_message, "Expected table output string"
    table_string = table_output_message[:message]
    assert_match(/Results displayed/, table_string)
  end

  def test_render_with_different_sort_orders
    # Add multiple results with different memory sizes
    results = [@baseline]  # 1MB

    # Add 2MB result
    results << Awfy::Result.new(
      type: :memory,
      runtime: Awfy::Runtimes::YJIT,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test2",
      branch: "main",
      baseline: false,
      timestamp: Time.now,
      result_data: {
        label: "2MB Test",
        allocated_memsize: 2_000_000,
        retained_memsize: 1_000_000,
        allocated_objects: 20_000,
        allocated_strings: 10_000
      }
    )

    # Add 500KB result
    results << Awfy::Result.new(
      type: :memory,
      runtime: Awfy::Runtimes::MRI,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test3",
      branch: "main",
      baseline: false,
      timestamp: Time.now,
      result_data: {
        label: "500KB Test",
        allocated_memsize: 500_000,
        retained_memsize: 250_000,
        allocated_objects: 5_000,
        allocated_strings: 2_500
      }
    )

    # Test descending order (default)
    @config = Awfy::Config.new(
      verbose: false,
      summary: true,
      summary_order: "desc"
    )
    @session = Awfy::Session.new(
      shell: @shell,
      config: @config,
      git_client: @git_client,
      results_store: @results_store
    )

    view = Awfy::Views::Memory::SummaryView.new(
      session: @session,
      group_name: "test_group",
      report_name: "test_report",
      test_name: nil,
      results: results,
      baseline: @baseline
    )

    view.render

    # Find the table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output, "Expected table output"
    table_string = table_output[:message]

    # Check that the order description is correct
    assert_includes table_string, "Results displayed in descending order (highest memory first)"

    # Test ascending order
    @shell.messages.clear
    @config = Awfy::Config.new(
      verbose: false,
      summary: true,
      summary_order: "asc"
    )
    @session = Awfy::Session.new(
      shell: @shell,
      config: @config,
      git_client: @git_client,
      results_store: @results_store
    )

    view = Awfy::Views::Memory::SummaryView.new(
      session: @session,
      group_name: "test_group",
      report_name: "test_report",
      test_name: nil,
      results: results,
      baseline: @baseline
    )

    view.render

    # Find the table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output, "Expected table output"
    table_string = table_output[:message]

    # Check that the order description is correct
    assert_includes table_string, "Results displayed in ascending order (lowest memory first)"
  end
end
