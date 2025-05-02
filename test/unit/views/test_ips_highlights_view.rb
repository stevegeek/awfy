# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/ips/highlights_view"

class TestIPSHighlightsView < ViewTestCase
  def setup
    super
    @view = Awfy::Views::IPS::HighlightsView.new(@shell, @options)
  end

  def test_build_table_headings
    # Test with both runtimes
    _, results_by_commit = generate_results_by_commit(2, true, true)
    headings = @view.send(:build_table_headings, results_by_commit)
    assert_equal ["Commit", "Description", "MRI IPS Change", "YJIT IPS Change", "YJIT vs MRI"], headings

    # Test with MRI only
    _, results_by_commit = generate_results_by_commit(2, true, false)
    headings = @view.send(:build_table_headings, results_by_commit)
    assert_equal ["Commit", "Description", "MRI IPS Change"], headings

    # Test with YJIT only
    _, results_by_commit = generate_results_by_commit(2, false, true)
    headings = @view.send(:build_table_headings, results_by_commit)
    assert_equal ["Commit", "Description", "YJIT IPS Change"], headings
  end

  def test_extract_baseline_data
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit)

    assert_equal sorted_commits.first, baseline_data[:commit]
    assert_equal results_by_commit[sorted_commits.first][:metadata], baseline_data[:metadata]
    assert_equal 1000.0, baseline_data[:mri_ips]
    assert_equal 1500.0, baseline_data[:yjit_ips]
  end

  def test_build_baseline_row
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit)

    row = @view.send(:build_baseline_row, baseline_data, results_by_commit)

    assert_equal 5, row.length
    assert_equal "000commi", row[0]
    assert_equal "Commit message 1", row[1]
    assert_equal "baseline", row[2] # MRI baseline
    assert_equal "baseline", row[3] # YJIT baseline
    assert_equal "1.5x", row[4]    # YJIT vs MRI
  end

  def test_build_commit_row
    sorted_commits, results_by_commit = generate_results_by_commit(3, true, true)
    baseline_data = @view.send(:extract_baseline_data, sorted_commits, results_by_commit)

    # Test second commit (non-baseline)
    commit = sorted_commits[1]
    row = @view.send(:build_commit_row, commit, baseline_data, results_by_commit)

    assert_equal 5, row.length
    assert_equal "000commi", row[0]
    assert_equal "Commit message 2", row[1]
    assert_equal "+100.0%", row[2]  # MRI IPS Change: 2000 vs 1000 = +100%
    assert_equal "+100.0%", row[3]  # YJIT IPS Change: 3000 vs 1500 = +100%
    assert_equal "1.5x", row[4]     # YJIT vs MRI: 3000 vs 2000 = 1.5x
  end

  def test_format_runtime_comparison
    # Test normal comparison
    assert_equal "1.5x", @view.send(:format_runtime_comparison, 1000.0, 1500.0)

    # Test with one nil value
    assert_equal "N/A", @view.send(:format_runtime_comparison, nil, 1500.0)
    assert_equal "N/A", @view.send(:format_runtime_comparison, 1000.0, nil)
    assert_equal "N/A", @view.send(:format_runtime_comparison, nil, nil)
  end

  def test_format_ips_change
    # Test normal comparison
    assert_equal "+50.0%", @view.send(:format_ips_change, 1500.0, 1000.0)
    assert_equal "-50.0%", @view.send(:format_ips_change, 500.0, 1000.0)
    assert_equal "No change", @view.send(:format_ips_change, 1000.0, 1000.0)

    # Test with one nil value
    assert_equal "N/A", @view.send(:format_ips_change, nil, 1000.0)
    assert_equal "N/A", @view.send(:format_ips_change, 1000.0, nil)
    assert_equal "N/A", @view.send(:format_ips_change, nil, nil)
  end

  def test_get_first_test_ips
    sorted_commits, results_by_commit = generate_results_by_commit(2, true, true)

    # Test MRI IPS
    ips = @view.send(:get_first_test_ips, results_by_commit, sorted_commits[0], :mri)
    assert_equal 1000.0, ips

    # Test YJIT IPS
    ips = @view.send(:get_first_test_ips, results_by_commit, sorted_commits[0], :yjit)
    assert_equal 1500.0, ips

    # Test non-existent runtime
    ips = @view.send(:get_first_test_ips, results_by_commit, sorted_commits[0], :truffleruby)
    assert_nil ips
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
    assert_includes table_string, "Performance Highlights"

    # Check that it contains expected headings
    assert_includes table_string, "Commit"
    assert_includes table_string, "Description"
    assert_includes table_string, "MRI IPS Change"
    assert_includes table_string, "YJIT IPS Change"
    assert_includes table_string, "YJIT vs MRI"

    # Check that baseline shows up
    assert_includes table_string, "baseline"

    # Check that percentage changes show up
    assert_match(/\+100/, table_string)
  end
end
