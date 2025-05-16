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
      test_name: "test1",
      branch: "main",
      baseline: true,
      timestamp: Time.now,
      result_data: {
        label: "Baseline Test",
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
      test_name: nil,
      results: [@baseline],
      baseline: @baseline
    )
  end

  def test_render_with_single_result
    # Call render
    @view.render

    # Check that output was generated
    assert @shell.messages.any?

    # Find the table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output, "Expected table output"

    # Check that the output includes expected headers
    table_string = table_output[:message]
    assert_includes table_string, "Branch"
    assert_includes table_string, "Runtime"
    assert_includes table_string, "Name"
    assert_includes table_string, "Allocated Memory"
    assert_includes table_string, "Retained Memory"
    assert_includes table_string, "Objects"
    assert_includes table_string, "Strings"
    assert_includes table_string, "vs Test"

    # Check that sorting order description was output
    assert_match(/Results displayed/, table_string)
  end

  def test_render_with_multiple_results
    # Add a non-baseline result
    results = [@baseline]
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
      results: results,
      baseline: @baseline
    )

    # Call render
    view.render

    # Check that output was generated
    assert @shell.messages.any?

    # Find the table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(String) && m[:message].include?("test_group/test_report") }
    refute_nil table_output, "Expected table output"

    # Check that both results are included
    table_string = table_output[:message]
    assert_includes table_string, "Baseline Test"
    assert_includes table_string, "Test Result"

    # Check that memory values are formatted correctly
    assert_includes table_string, "1.0M"  # Baseline allocated memory
    assert_includes table_string, "2.0M"  # Test result allocated memory

    # Check that sorting order description was output
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
