# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class SqliteStoreTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @test_dir = Dir.mktmpdir

    # Set the database path
    @db_path = File.join(@test_dir, "test_results")

    # Create retention policy
    retention_policy = Awfy::RetentionPolicies.keep_all

    # Create the Sqlite store instance to test
    @store = Awfy::Stores::Sqlite.new(storage_name: @db_path, retention_policy: retention_policy)

    # SQLite is required for these tests

    # Verify the database file was created
    assert File.exist?("#{@db_path}.db"), "Database file should exist"
  end

  def teardown
    # Clean up the temporary directory
    FileUtils.remove_entry(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_save_result
    # Create test metadata
    metadata = Awfy::Result.new(
      type: :ips,
      group: "Test Group",
      report: "#method_name",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "abc123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
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
    assert_instance_of Awfy::Result, stored_metadata
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

  def test_query_results
    # Store multiple results first
    timestamp = Time.now.to_i

    # Store result 1
    metadata1 = Awfy::Result.new(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: nil
    )

    @store.save_result(metadata1) do
      {ips: 1000.0}
    end

    # Store result 2 with different runtime
    metadata2 = Awfy::Result.new(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "yjit",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: nil
    )

    @store.save_result(metadata2) do
      {ips: 1500.0}
    end

    # Store result 3 with different group
    metadata3 = Awfy::Result.new(
      type: :ips,
      group: "Another Group",
      report: "#method2",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
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
    assert_instance_of Awfy::Result, results.first
    assert_equal 1500.0, results.first.result_data["ips"], "Should find the correct result"

    # Query with combination of filters
    results = @store.query_results(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "ruby"
    )
    assert_equal 1, results.length, "Should find 1 result matching all criteria"
    assert_instance_of Awfy::Result, results.first
    assert_equal 1000.0, results.first.result_data["ips"], "Should find the correct result"

    # Query with commit filter
    results = @store.query_results(type: :ips, commit: "query1")
    assert_equal 3, results.length, "Should find 3 results for commit query1"
  end

  def test_load_result
    # Store a result to load later
    metadata = Awfy::Result.new(
      type: :ips,
      group: "Load Test",
      report: "#load_method",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "load123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: nil
    )

    result_data = {ips: 3000.0, iterations: 5000}

    # Store the result
    result_id = @store.save_result(metadata) do
      result_data
    end

    # Load the result by ID
    loaded_result = @store.load_result(result_id)

    # Verify loaded result is a Result object
    assert_instance_of Awfy::Result, loaded_result

    # Verify loaded data matches original
    assert_equal result_data[:ips], loaded_result.result_data["ips"]
    assert_equal result_data[:iterations], loaded_result.result_data["iterations"]

    # Attempt to load non-existent result
    assert_nil @store.load_result("non-existent-id"), "Should return nil for non-existent ID"
  end

  def test_clean_results
    # Store some results
    metadata_temp = Awfy::Result.new(
      type: :clean_test,
      group: "Clean Group",
      report: "#temp",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "clean1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: nil
    )

    @store.save_result(metadata_temp) do
      {data: "temp data"}
    end

    # Store additional results
    metadata_perm = Awfy::Result.new(
      type: :clean_test,
      group: "Clean Group",
      report: "#perm",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "clean2",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: nil
    )

    @store.save_result(metadata_perm) do
      {data: "perm data"}
    end

    # Verify both results exist
    results = @store.query_results(type: :clean_test)
    assert_equal 2, results.length, "Should have 2 results before cleaning"

    # Clean with KeepAll retention policy (should keep everything)
    @store.clean_results

    # Verify results after cleaning
    results = @store.query_results(type: :clean_test)
    # With KeepAll retention policy, all results should be kept
    assert_equal 2, results.length, "Both results should remain with KeepAll retention policy"

    # Create a store with KeepNone policy to remove all results
    keep_none_policy = Awfy::RetentionPolicies.keep_none
    keep_none_store = Awfy::Stores::Sqlite.new(storage_name: @db_path, retention_policy: keep_none_policy)

    # Clean with KeepNone policy
    keep_none_store.clean_results

    # Verify no results remain
    results = keep_none_store.query_results(type: :clean_test)
    assert_equal 0, results.length, "Should have 0 results after cleaning with KeepNone policy"
  end
end
