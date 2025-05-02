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
    stored_data = @store.load_result(result_id)
    assert_equal result_data[:iterations], stored_data["iterations"]
    assert_equal result_data[:runtime], stored_data["runtime"]
    assert_equal result_data[:ips], stored_data["ips"]

    # Query metadata and verify it contains our entry
    metadata_entries = @store.get_metadata(:ips)
    assert metadata_entries.length > 0, "Should find metadata entries for ips"

    # Find our entry
    our_entry = metadata_entries.find { |entry| entry["result_id"] == result_id }
    assert our_entry, "Should find our metadata entry"

    # Verify metadata content
    assert_equal "Test Group", our_entry["group"]
    assert_equal "#method_name", our_entry["report"]
    assert_equal "ruby", our_entry["runtime"]
    assert_equal "main", our_entry["branch"]
    assert_equal "abc123", our_entry["commit"]
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

    # Query metadata and verify it's flagged as permanent
    metadata_entries = @store.get_metadata(:memory)
    our_entry = metadata_entries.find { |entry| entry["result_id"] == result_id }
    assert our_entry, "Should find our metadata entry"

    # The "save" flag should be reflected in the is_temp flag (inverted)
    refute our_entry["is_temp"], "Result should be saved as permanent"
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
      result_id: nil,
      output_path: nil
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
      result_id: nil,
      output_path: nil
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

  def test_get_metadata
    # Store some results for metadata retrieval
    timestamp = Time.now.to_i

    # Store for type1
    metadata1 = Awfy::ResultMetadata.new(
      type: :meta_type1,
      group: "Meta Group",
      report: "#meta1",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "meta1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata1) do
      {data: "meta_type1 data"}
    end

    # Store for type2
    metadata2 = Awfy::ResultMetadata.new(
      type: :meta_type2,
      group: "Meta Group",
      report: "#meta1",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "meta2",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata2) do
      {data: "meta_type2 data"}
    end

    # Get metadata for type1
    metadata_entries = @store.get_metadata(:meta_type1)
    assert_equal 1, metadata_entries.length, "Should find 1 metadata entry for meta_type1"
    assert_equal "Meta Group", metadata_entries.first["group"]
    assert_equal "#meta1", metadata_entries.first["report"]

    # Get metadata with group filter
    metadata_entries = @store.get_metadata(:meta_type2, "Meta Group")
    assert_equal 1, metadata_entries.length, "Should find 1 metadata entry for meta_type2 + Meta Group"

    # Get metadata with group and report filter
    metadata_entries = @store.get_metadata(:meta_type2, "Meta Group", "#meta1")
    assert_equal 1, metadata_entries.length, "Should find 1 metadata entry for all filters"

    # Get metadata for non-existent type
    metadata_entries = @store.get_metadata(:nonexistent)
    assert_equal 0, metadata_entries.length, "Should find 0 metadata entries for nonexistent type"
  end

  def test_list_results
    # Store some results for listing
    timestamp = Time.now.to_i

    # Store for type1, group1
    metadata1 = Awfy::ResultMetadata.new(
      type: :list_type1,
      group: "List Group 1",
      report: "#list1",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "list1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata1) do
      {data: "list data 1"}
    end

    # Store for type1, group2
    metadata2 = Awfy::ResultMetadata.new(
      type: :list_type1,
      group: "List Group 2",
      report: "#list2",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "list2",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata2) do
      {data: "list data 2"}
    end

    # Store for type2, group1
    metadata3 = Awfy::ResultMetadata.new(
      type: :list_type2,
      group: "List Group 1",
      report: "#list3",
      runtime: "ruby",
      timestamp: timestamp,
      branch: "main",
      commit: "list3",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata3) do
      {data: "list data 3"}
    end

    # List all results
    results = @store.list_results

    # Verify the structure of results
    assert_equal 2, results.size, "Results should include 2 types"

    # Verify the data for list_type1
    assert results.key?("list_type1"), "Results should include list_type1"
    assert_equal 2, results["list_type1"].size, "list_type1 should have 2 groups"
    assert results["list_type1"].key?("List Group 1"), "list_type1 should include List Group 1"
    assert results["list_type1"].key?("List Group 2"), "list_type1 should include List Group 2"
    assert_equal ["#list1"], results["list_type1"]["List Group 1"], "Should find correct report for Group 1"
    assert_equal ["#list2"], results["list_type1"]["List Group 2"], "Should find correct report for Group 2"

    # Verify the data for list_type2
    assert results.key?("list_type2"), "Results should include list_type2"
    assert_equal 1, results["list_type2"].size, "list_type2 should have 1 group"
    assert results["list_type2"].key?("List Group 1"), "list_type2 should include List Group 1"
    assert_equal ["#list3"], results["list_type2"]["List Group 1"], "Should find correct report for list_type2 Group 1"

    # List results for specific type
    type1_results = @store.list_results("list_type1")
    assert_equal 1, type1_results.size, "Type1 results should only have 1 type"
    assert type1_results.key?("list_type1"), "Type1 results should include list_type1"
    refute type1_results.key?("list_type2"), "Type1 results should not include list_type2"
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
      result_id: nil,
      output_path: nil
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
      result_id: nil,
      output_path: nil
    )

    @store.save_result(metadata_perm) do
      {data: "perm data"}
    end

    # Verify both results exist
    results = @store.get_metadata(:clean_test)
    assert_equal 2, results.length, "Should have 2 results before cleaning"

    # Clean temporary results only
    @store.clean_results(temp_only: true)

    # Verify only permanent results remain
    results = @store.get_metadata(:clean_test)
    assert_equal 1, results.length, "Should have 1 result after cleaning temp"
    assert_equal "#perm", results.first["report"], "Permanent result should remain"

    # Clean all results
    @store.clean_results(temp_only: false)

    # Verify no results remain
    results = @store.get_metadata(:clean_test)
    assert_equal 0, results.length, "Should have 0 results after cleaning all"
  end
end
