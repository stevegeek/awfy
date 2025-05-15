# frozen_string_literal: true

require_relative "integration_test_helper"

class IPSCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
  end

  def teardown
    teardown_test_environment
  end

  def test_ips_command_runs_and_produces_output
    # Run IPS with minimal warmup and test time (handled by helper)
    output = run_command("ips")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Test for progress indicator
    assert_match(/Running:/, output)
  end

  def test_ips_command_with_summary
    # Run IPS with minimal warmup and test time and summary output
    # The summary setting is default so no need to specify
    output = run_command("ips")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Test that report names are included
    assert_match(/#+/, output)

    # Test that different runtimes are included
    assert_match(/\[mri/, output)
    assert_match(/\[yjit/, output)

    # Check for table output which should be present with summary - now using table_tennis format
    assert_match(/timestamp/i, output)
    assert_match(/branch/i, output)
    assert_match(/runtime/i, output)
  end

  def test_ips_summary_view_structure
    # Run IPS command with summary output
    output = run_command("ips", options: {summary: true, summary_order: "foo"})

    # Verify table header has expected columns - using table_tennis format
    assert_match(/timestamp/i, output)
    assert_match(/branch/i, output)
    assert_match(/commit/i, output)
    assert_match(/runtime/i, output)
    assert_match(/control/i, output)
    assert_match(/baseline/i, output)
    assert_match(/name/i, output)
    assert_match(/ips/i, output)

    # Simple check for patterns that should appear in the output
    assert_match(/\d{4}-\d{2}-\d{2}/, output) # Date pattern
    assert_match(/\?/, output) # Branch info
    assert_match(/mri/, output) # Runtime name
    assert_match(/\d+\.\d+[kM]/, output) # IPS value with units

    assert_match(/Results displayed as a leaderboard/, output)
  end

  def test_ips_command_stores_results
    # Run IPS command
    run_command("ips")

    # Create a new SQLite store pointing to the same unique database file used by the command
    retention_policy = Awfy::RetentionPolicies.keep_all
    result_store = Awfy::Stores.sqlite(@test_db_path, retention_policy)

    # Query for all IPS results
    results = result_store.query_results(type: :ips)

    # Check that results were stored
    refute_empty results, "No results were stored in the SQLite store"

    # Verify each stored result has the expected structure with samples
    results.each do |result|
      # Check result type is :ips
      assert_equal :ips, result.type

      # Verify data structure
      refute_nil result.result_data, "Result data should not be nil"
      assert_kind_of Hash, result.result_data, "Result data should be a hash"

      # Check required keys exist in the hash
      entry = result.result_data
      assert entry.key?(:measured_us), "Entry should have measured_us"
      assert entry.key?(:iter), "Entry should have iter (iterations)"
      assert entry.key?(:samples), "Entry should have samples"
      assert entry.key?(:control), "Entry should have control flag"
      assert entry.key?(:cycles), "Entry should have cycles"

      # Check label is available from the Result object
      assert_kind_of String, result.label, "Result should have a label"
      assert_kind_of Float, entry[:measured_us], "measured_us should be a float"
      assert_kind_of Integer, entry[:iter], "iterations should be an integer"
      assert_kind_of Array, entry[:samples], "samples should be an array"
      assert_kind_of TrueClass, entry[:control], "control should be a boolean" if entry[:control]
      assert_kind_of FalseClass, entry[:control], "control should be a boolean" if !entry[:control]
      assert_kind_of Integer, entry[:cycles], "cycles should be an integer"

      # Verify samples contains numeric values
      refute_empty entry[:samples], "Samples array should not be empty"
      entry[:samples].each do |sample|
        assert_kind_of Numeric, sample, "Sample should be a numeric value"
      end
    end
  end
end
