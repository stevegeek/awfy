# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/memory/highlights_view"
require "bigdecimal"

class TestMemoryHighlightsView < ViewTestCase
  def setup
    super
    @view = Awfy::Views::Memory::HighlightsView.new(@shell, @options)
  end

  def test_select_runtime
    # Test with MRI available
    _, results_by_commit = generate_results_by_commit(2, true, true)
    runtime = @view.send(:select_runtime, results_by_commit)
    assert_equal :mri, runtime

    # Test with YJIT only
    _, results_by_commit = generate_results_by_commit(2, false, true)
    runtime = @view.send(:select_runtime, results_by_commit)
    assert_equal :yjit, runtime
  end

  def test_extract_baseline_data
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)

    # Test with MRI runtime
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit, :mri)

    assert_equal sorted_commits.first, baseline_data[:commit]
    assert_equal results_by_commit[sorted_commits.first][:metadata], baseline_data[:metadata]
    assert_equal 100000, baseline_data[:memory]
    assert_equal 1000, baseline_data[:objects]

    # Test with non-existent runtime
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit, :truffleruby)
    assert_nil baseline_data

    # Test with no memory data
    bad_results = {
      "commit1" => {
        metadata: {commit_message: "No memory data"},
        mri: [{"item" => "test1", "ips" => 1000.0}]  # No memory key
      }
    }
    bad_sorted = ["commit1"]

    baseline_data = @view.send(:extract_baseline_data, bad_sorted, bad_results, :mri)
    assert_nil baseline_data
  end

  def test_build_baseline_row
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit, :mri)

    row = @view.send(:build_baseline_row, baseline_data)

    assert_equal 4, row.length
    assert_equal "000commi", row[0]
    assert_equal "Commit message 1", row[1]
    assert_equal "baseline", row[2] # Memory baseline
    assert_equal "baseline", row[3] # Objects baseline
  end

  def test_build_commit_row
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit, :mri)

    # Test second commit (non-baseline)
    commit = sorted_commits[1]
    row = @view.send(:build_commit_row, commit, baseline_data, results_by_commit, :mri)

    assert_equal 4, row.length
    assert_equal "000commi", row[0]
    assert_equal "Commit message 2", row[1]
    assert_equal "+100.0%", row[2]  # Memory Change: 200000 vs 100000 = +100%
    assert_equal "+100.0%", row[3]  # Objects Change: 2000 vs 1000 = +100%

    # Test with missing memory data
    bad_results = {
      "commit1" => {
        metadata: {commit_message: "Baseline"},
        mri: [{"item" => "test1", "memory" => {"memsize" => 100000, "objects" => 1000}}]
      },
      "commit2" => {
        metadata: {commit_message: "No memory data"},
        mri: [{"item" => "test1"}]  # No memory key
      }
    }
    bad_sorted = ["commit1", "commit2"]

    baseline_data = @view.send(:extract_baseline_data, bad_sorted, bad_results, :mri)
    row = @view.send(:build_commit_row, "commit2", baseline_data, bad_results, :mri)

    assert_equal 4, row.length
    assert_equal "commit2", row[0]
    assert_equal "No memory data", row[1]
    assert_equal "N/A", row[2]  # No memory data
    assert_equal "N/A", row[3]  # No objects data
  end

  def test_format_memory_change
    # Test normal comparison
    assert_equal "+50.0%", @view.send(:format_memory_change, 150000, 100000)
    assert_equal "-50.0%", @view.send(:format_memory_change, 50000, 100000)
    assert_equal "No change", @view.send(:format_memory_change, 100000, 100000)

    # Test with one nil value
    assert_equal "N/A", @view.send(:format_memory_change, nil, 100000)
    assert_equal "N/A", @view.send(:format_memory_change, 100000, nil)
    assert_equal "N/A", @view.send(:format_memory_change, nil, nil)

    # Test with BigDecimal input
    memory1 = BigDecimal(150000)
    memory2 = BigDecimal(100000)
    assert_equal "+50.0%", @view.send(:format_memory_change, memory1, memory2)
  end

  def test_find_first_test_with_memory
    sorted_commits, results_by_commit = generate_results_by_commit(2, true, true)

    # Test MRI with memory
    result = @view.send(:find_first_test_with_memory, results_by_commit, sorted_commits[0], :mri)
    refute_nil result
    refute_nil result["memory"]
    assert_equal 100000, result["memory"]["memsize"]

    # Test non-existent runtime
    result = @view.send(:find_first_test_with_memory, results_by_commit, sorted_commits[0], :truffleruby)
    assert_nil result

    # Test non-existent commit
    result = @view.send(:find_first_test_with_memory, results_by_commit, "nonexistent", :mri)
    assert_nil result
  end

  def test_highlights_table
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)

    @view.highlights_table(sorted_commits, results_by_commit)

    # Check that output was generated
    assert @shell.messages.any?

    # Find the terminal table output
    table_output = @shell.messages.find { |m| m[:message].is_a?(Terminal::Table) }
    refute_nil table_output

    # Check that header contains expected title
    table_string = table_output[:message].to_s
    assert_includes table_string, "Memory Highlights"

    # Check that it contains expected headings
    assert_includes table_string, "Commit"
    assert_includes table_string, "Description"
    assert_includes table_string, "Memory Change"
    assert_includes table_string, "Objects Change"

    # Check that baseline shows up
    assert_includes table_string, "baseline"

    # Check that percentage changes show up
    assert_match(/\+100/, table_string)
  end

  def test_highlights_table_with_no_baseline_data
    # Create results with no memory data
    results_by_commit = {
      "commit1" => {
        metadata: {commit_message: "No memory data"},
        mri: [{"item" => "test1", "ips" => 1000.0}]  # No memory key
      }
    }
    sorted_commits = ["commit1"]

    @view.highlights_table(sorted_commits, results_by_commit)

    # Check that error message was displayed
    assert_includes @shell.messages.map { |m| m[:message] }, "No baseline memory data available for comparison"

    # Check that no table was generated
    table_output = @shell.messages.find { |m| m[:message].is_a?(Terminal::Table) }
    assert_nil table_output
  end
end
