# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class MemoryCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
  end

  def teardown
    teardown_test_environment
  end

  def test_memory_command_runs_and_produces_output
    # Run memory profiling
    output = run_command("memory")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Check for progress indicator
    assert_match(/Progress:/, output)
  end

  def test_memory_command_with_summary
    # Run memory command with summary output (default)
    output = run_command("memory")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Test for table structure
    assert_match(/\+-+\+-+\+-+\+-+\+-+\+/, output)

    # Test for column headers
    assert_match(/\|\s+Timestamp\s+\|\s+Branch\s+\|\s+Runtime\s+\|\s+Name\s+\|\s+Allocated Memory\s+\|/, output)

    # Test for memory values
    assert_match(/\|\s+\d+\.\d+[kM]\s+\|/, output)

    # Test for leaderboard description
    assert_match(/Results displayed/, output)

    # Test that different runtimes are included
    assert_match(/\[mri/, output)
    assert_match(/\[yjit/, output)
  end

  def test_memory_command_stores_results
    # Run memory command
    run_command("memory")

    # Create a new SQLite store pointing to the same unique database file used by the command
    retention_policy = Awfy::RetentionPolicies.keep_all
    result_store = Awfy::Stores.sqlite(@test_db_path, retention_policy)

    # Query for all memory results
    results = result_store.query_results(type: :memory)

    # Check that results were stored
    refute_empty results, "No results were stored in the SQLite store"

    # Verify each stored result has the expected structure
    results.each do |result|
      # Check result type is :memory
      assert_equal :memory, result.type

      # Verify data structure
      refute_nil result.result_data, "Result data should not be nil"
      assert_kind_of Hash, result.result_data, "Result data should be a hash"

      # Check required keys exist in the hash
      assert result.result_data.key?(:allocated_memsize), "Entry should have allocated_memsize"
      assert result.result_data.key?(:allocated_objects), "Entry should have allocated_objects"
      assert result.result_data.key?(:retained_memsize), "Entry should have retained_memsize"
      assert result.result_data.key?(:retained_objects), "Entry should have retained_objects"
      assert result.result_data.key?(:retained_strings), "Entry should have retained_strings"
      assert result.result_data.key?(:allocated_strings), "Entry should have allocated_strings"

      # Check data types - ensuring basic fields are present
      # The actual types may vary between Integer or Array in some memory profiler output fields
      refute_nil result.result_data[:allocated_memsize], "allocated_memsize should not be nil"
      refute_nil result.result_data[:allocated_objects], "allocated_objects should not be nil"
      refute_nil result.result_data[:retained_memsize], "retained_memsize should not be nil"
      refute_nil result.result_data[:retained_objects], "retained_objects should not be nil"
      refute_nil result.result_data[:retained_strings], "retained_strings should not be nil"
      refute_nil result.result_data[:allocated_strings], "allocated_strings should not be nil"
    end
  end
end
