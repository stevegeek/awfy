# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class SqliteResultStoreTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment

    # Create specific directories for this test
    @temp_dir = File.join(@test_dir, "temp_results")
    @results_dir = File.join(@test_dir, "saved_results")
    FileUtils.mkdir_p(@temp_dir)
    FileUtils.mkdir_p(@results_dir)

    # Create options with our test directories
    @options = Awfy::Options.new(
      temp_output_directory: @temp_dir,
      results_directory: @results_dir
    )

    # Create the SqliteResultStore instance to test
    @store = Awfy::SqliteResultStore.new(@options)

    # SQLite is required for these tests
    # The factory should raise an error if SQLite is not available

    # Verify the database file was created
    assert File.exist?(File.join(@results_dir, "awfy_benchmarks.db")), "Database file should exist"
  end

  def teardown
    teardown_test_environment
  end

  def test_save_result
    # Create test metadata
    metadata = Awfy::ResultMetadata.new(
      type: :ips,
      group: "Test Group",
      report: "#method_name",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "abc123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil
    )

    # Sample benchmark result data
    result_data = {
      iterations: 1000,
      runtime: 0.5,
      ips: 2000.0
    }

    # Store the result
    result_id = @store.save_result(metadata) do
      result_data
    end

    # Assert that the result_id is returned
    assert result_id, "Result ID should be returned"

    # Load stored data and verify it matches original
    stored_metadata = @store.load_result(result_id)
    assert_instance_of Awfy::ResultMetadata, stored_metadata
    stored_data = stored_metadata.result_data
    assert_equal result_data[:iterations], stored_data["iterations"]
    assert_equal result_data[:runtime], stored_data["runtime"]
    assert_equal result_data[:ips], stored_data["ips"]

    # Use query_results to verify metadata
    metadata_entries = @store.query_results(type: :ips)
    assert metadata_entries.length > 0, "Should find metadata entries for ips"

    # Find our entry
    our_entry = metadata_entries.find { |entry| entry.result_id == result_id }
    assert our_entry, "Should find our metadata entry"

    # Verify metadata content
    assert_equal "Test Group", our_entry.group
    assert_equal "#method_name", our_entry.report
    assert_equal "ruby", our_entry.runtime
    assert_equal "main", our_entry.branch
    assert_equal "abc123", our_entry.commit
  end

  def test_save_result_with_save_flag
    # Create test metadata with save=true
    metadata = Awfy::ResultMetadata.new(
      type: :memory,
      group: "Test Group",
      report: "#memory_test",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "def456",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: true,  # This should cause it to be saved permanently
      result_id: nil
    )

    # Sample benchmark result data
    result_data = {
      memory: 1024,
      objects: 50
    }

    # Store the result
    result_id = @store.save_result(metadata) do
      result_data
    end

    # Assert that the result_id is returned
    assert result_id, "Result ID should be returned"

    # Query results and verify it's flagged as permanent
    metadata_entries = @store.query_results(type: :memory)
    our_entry = metadata_entries.find { |entry| entry.result_id == result_id }
    assert our_entry, "Should find our metadata entry"

    # The "save" flag should be true for permanent entries
    assert our_entry.save, "Result should be saved as permanent"
  end

  def test_query_results
    # Store multiple results first
    timestamp = Time.now.to_i

    # Store result 1
    metadata1 = Awfy::ResultMetadata.new(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil
    )

    @store.save_result(metadata1) do
      {ips: 1000.0}
    end

    # Store result 2 with different runtime
    metadata2 = Awfy::ResultMetadata.new(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "yjit",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil
    )

    @store.save_result(metadata2) do
      {ips: 1500.0}
    end

    # Store result 3 with different group
    metadata3 = Awfy::ResultMetadata.new(
      type: :ips,
      group: "Another Group",
      report: "#method2",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil
    )

    @store.save_result(metadata3) do
      {ips: 2000.0}
    end

    # Query for all ips results
    results = @store.query_results(type: :ips)
    assert_equal 3, results.length, "Should find 3 ips results"

    # Query with group filter
    results = @store.query_results(type: :ips, group: "Query Group")
    assert_equal 2, results.length, "Should find 2 results for Query Group"

    # Query with runtime filter
    results = @store.query_results(type: :ips, runtime: "yjit")
    assert_equal 1, results.length, "Should find 1 result for yjit runtime"
    assert_instance_of Awfy::ResultMetadata, results.first
    assert_equal 1500.0, results.first.result_data["ips"], "Should find the correct result"

    # Query with combination of filters
    results = @store.query_results(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "ruby"
    )
    assert_equal 1, results.length, "Should find 1 result matching all criteria"
    assert_instance_of Awfy::ResultMetadata, results.first
    assert_equal 1000.0, results.first.result_data["ips"], "Should find the correct result"

    # Query with commit filter
    results = @store.query_results(type: :ips, commit: "query1")
    assert_equal 3, results.length, "Should find 3 results for commit query1"
  end

  def test_load_result
    # Store a result to load later
    metadata = Awfy::ResultMetadata.new(
      type: :ips,
      group: "Load Test",
      report: "#load_method",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "load123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil
    )

    result_data = {ips: 3000.0, iterations: 5000}

    # Store the result
    result_id = @store.save_result(metadata) do
      result_data
    end

    # Load the result by ID
    loaded_result = @store.load_result(result_id)

    # Verify loaded result is a ResultMetadata object
    assert_instance_of Awfy::ResultMetadata, loaded_result

    # Verify loaded data matches original
    assert_equal result_data[:ips], loaded_result.result_data["ips"]
    assert_equal result_data[:iterations], loaded_result.result_data["iterations"]

    # Attempt to load non-existent result
    assert_nil @store.load_result("non-existent-id"), "Should return nil for non-existent ID"
  end

  def test_clean_results
    # Store some temporary results
    metadata_temp = Awfy::ResultMetadata.new(
      type: :clean_test,
      group: "Clean Group",
      report: "#temp",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "clean1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,  # temporary
      result_id: nil
    )

    @store.save_result(metadata_temp) do
      {data: "temp data"}
    end

    # Store some permanent results
    metadata_perm = Awfy::ResultMetadata.new(
      type: :clean_test,
      group: "Clean Group",
      report: "#perm",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "clean2",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: true,  # permanent
      result_id: nil
    )

    @store.save_result(metadata_perm) do
      {data: "perm data"}
    end

    # Verify both results exist
    results = @store.query_results(type: :clean_test)
    assert_equal 2, results.length, "Should have 2 results before cleaning"

    # Clean temporary results only
    @store.clean_results(temp_only: true)

    # Verify only permanent results remain
    results = @store.query_results(type: :clean_test)
    assert_equal 1, results.length, "Should have 1 result after cleaning temp"
    assert_equal "#perm", results.first.report, "Permanent result should remain"

    # Clean all results
    @store.clean_results(temp_only: false)

    # Verify no results remain
    results = @store.query_results(type: :clean_test)
    assert_equal 0, results.length, "Should have 0 results after cleaning all"
  end
end
