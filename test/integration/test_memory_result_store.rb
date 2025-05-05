# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class MemoryResultStoreTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment

    # Create options with our test directories
    @options = Awfy::Options.new(
      storage_backend: :memory
    )

    # Create the Memory store instance to test
    @store = Awfy::Stores::Memory.new(@options)
  end

  def teardown
    teardown_test_environment
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
      save: false,
      result_id: nil,
      result_data: nil
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

    # Verify stored result exists
    refute_empty @store.stored_results, "No results were stored in the memory store"

    # Verify result_id is stored
    assert @store.stored_results.key?(result_id), "Result ID should be present in stored results"

    # Check stored data structure
    stored_result = @store.stored_results[result_id]
    assert_instance_of Awfy::Result, stored_result, "Stored result should be a Result object"
    assert_equal :ips, stored_result.type, "Result type should match"
    assert_equal "Test Group", stored_result.group, "Result group should match"
    assert_equal "ruby", stored_result.runtime, "Result runtime should match"
    assert_equal "main", stored_result.branch, "Result branch should match"
    assert_equal result_data, stored_result.result_data, "Result data should match"
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
      save: false,
      result_id: nil,
      result_data: nil
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
      save: false,
      result_id: nil,
      result_data: nil
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
      save: false,
      result_id: nil,
      result_data: nil
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
    assert_equal 1500.0, results.first.result_data[:ips], "Should find the correct result"

    # Query with combination of filters
    results = @store.query_results(
      type: :ips,
      group: "Query Group",
      report: "#method1",
      runtime: "ruby"
    )
    assert_equal 1, results.length, "Should find 1 result matching all criteria"
    assert_instance_of Awfy::Result, results.first
    assert_equal 1000.0, results.first.result_data[:ips], "Should find the correct result"

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
      save: false,
      result_id: nil,
      result_data: nil
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
    assert_equal result_data[:ips], loaded_result.result_data[:ips]
    assert_equal result_data[:iterations], loaded_result.result_data[:iterations]

    # Attempt to load non-existent result
    assert_nil @store.load_result("non-existent-id"), "Should return nil for non-existent ID"
  end

  def test_clean_results
    # Add a result to the store
    metadata = Awfy::Result.new(
      type: :ips,
      group: "Clean Test",
      report: "#clean_method",
      runtime: "ruby",
      timestamp: Time.now.to_i,
      branch: "main",
      commit: "clean123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      save: false,
      result_id: nil,
      result_data: nil
    )

    @store.save_result(metadata) do
      {data: "test data"}
    end

    # Verify result was added
    refute_empty @store.stored_results, "Result should be added to store"

    # Clean results
    @store.clean_results

    # Verify store is now empty
    assert_empty @store.stored_results, "Store should be empty after cleaning"
  end
end