# frozen_string_literal: true

require "test_helper"

class MemoryStoreTest < Minitest::Test
  def setup
    # Create retention policy
    retention_policy = Awfy::RetentionPolicies.keep_all

    # Create the Memory store instance to test
    @store = Awfy::Stores::Memory.new(storage_name: "test_memory_store", retention_policy: retention_policy)
  end

  def test_save_result
    # Create test metadata
    metadata = Awfy::Result.new(
      type: :ips,
      group_name: "Test Group",
      report_name: "#method_name",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now,
      branch: "main",
      commit: "abc123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test",
      result_data: {}
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
    assert_equal "Test Group", stored_result.group_name, "Result group should match"
    assert_equal Awfy::Runtimes::MRI, stored_result.runtime, "Result runtime should match"
    assert_equal "main", stored_result.branch, "Result branch should match"
    assert_equal result_data, stored_result.result_data, "Result data should match"
  end

  def test_query_results
    # Store multiple results first
    timestamp = Time.now

    # Store result 1
    metadata1 = Awfy::Result.new(
      type: :ips,
      group_name: "Query Group",
      report_name: "#method1",
      runtime: Awfy::Runtimes::MRI,
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test",
      result_data: {}
    )

    @store.save_result(metadata1) do
      {ips: 1000.0}
    end

    # Store result 2 with different runtime
    metadata2 = Awfy::Result.new(
      type: :ips,
      group_name: "Query Group",
      report_name: "#method1",
      runtime: Awfy::Runtimes::YJIT,
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test",
      result_data: {}
    )

    @store.save_result(metadata2) do
      {ips: 1500.0}
    end

    # Store result 3 with different group
    metadata3 = Awfy::Result.new(
      type: :ips,
      group_name: "Another Group",
      report_name: "#method2",
      runtime: Awfy::Runtimes::MRI,
      timestamp: timestamp,
      branch: "main",
      commit: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test3",
      result_data: {}
    )

    @store.save_result(metadata3) do
      {ips: 2000.0}
    end

    # Query for all ips results
    results = @store.query_results(type: :ips)
    assert_equal 3, results.length, "Should find 3 ips results"

    # Query with group filter
    results = @store.query_results(type: :ips, group_name: "Query Group")
    assert_equal 2, results.length, "Should find 2 results for Query Group"

    # Query with runtime filter
    results = @store.query_results(type: :ips, runtime: "yjit")
    assert_equal 1, results.length, "Should find 1 result for yjit runtime"
    assert_instance_of Awfy::Result, results.first
    assert_equal 1500.0, results.first.result_data[:ips], "Should find the correct result"

    # Query with combination of filters
    results = @store.query_results(
      type: :ips,
      group_name: "Query Group",
      report_name: "#method1",
      runtime: "mri"
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
      group_name: "Load Test",
      report_name: "#load_method",
      runtime: Awfy::Runtimes::YJIT,
      timestamp: Time.now,
      branch: "main",
      commit: "load123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test",
      result_data: {}
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
      group_name: "Clean Test",
      report_name: "#clean_method",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now,
      branch: "main",
      commit: "clean123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test",
      result_data: {}
    )

    @store.save_result(metadata) do
      {data: "test data"}
    end

    # Verify result was added
    refute_empty @store.stored_results, "Result should be added to store"

    # Clean results with KeepAll policy (should keep everything)
    @store.clean_results

    # Verify results are still there
    refute_empty @store.stored_results, "Results should be kept with KeepAll policy"

    # Create a store with KeepNone policy to remove all results
    keep_none_policy = Awfy::RetentionPolicies.keep_none
    keep_none_store = Awfy::Stores::Memory.new(storage_name: "test_memory_store", retention_policy: keep_none_policy)

    # Copy results to the new store
    keep_none_store.instance_variable_set(:@stored_results, @store.stored_results.dup)

    # Clean results with KeepNone policy
    keep_none_store.clean_results

    # Verify store is now empty
    assert_empty keep_none_store.stored_results, "Store should be empty after cleaning with KeepNone policy"
  end

  def test_concurrent_save_results
    # Number of threads to use
    thread_count = 10
    results_per_thread = 100
    total_results = thread_count * results_per_thread

    # Create threads that will save results concurrently
    threads = thread_count.times.map do |thread_index|
      Thread.new do
        results_per_thread.times do |i|
          # Create unique metadata for this thread's result
          metadata = Awfy::Result.new(
            type: :ips,
            group_name: "Concurrent Test",
            report_name: "#thread_#{thread_index}_result_#{i}",
            runtime: Awfy::Runtimes::MRI,
            timestamp: Time.now,
            branch: "main",
            commit: "concurrent123",
            commit_message: "Test concurrent saves",
            ruby_version: "3.1.0",
            result_id: "test",
            result_data: {}
          )

          # Save result with thread-specific data
          @store.save_result(metadata) do
            {
              thread: thread_index,
              iteration: i,
              data: "Thread #{thread_index} Result #{i}"
            }
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    # Verify the total number of results
    assert_equal total_results, @store.stored_results.size,
      "Should have saved all results from all threads"

    # Verify result IDs are unique
    result_ids = @store.stored_results.keys
    assert_equal result_ids.uniq.size, result_ids.size,
      "All result IDs should be unique"

    # Verify @next_id was properly incremented
    assert_equal total_results + 1, @store.instance_variable_get(:@next_id),
      "@next_id should match total number of results"

    # Verify data integrity - each thread's results should be present and correct
    thread_count.times do |thread_index|
      results_per_thread.times do |i|
        # Find the result for this thread and iteration
        result = @store.query_results(
          type: :ips,
          group_name: "Concurrent Test",
          report_name: "#thread_#{thread_index}_result_#{i}"
        ).first

        assert result, "Should find result for thread #{thread_index}, iteration #{i}"
        assert_equal thread_index, result.result_data[:thread],
          "Result should have correct thread index"
        assert_equal i, result.result_data[:iteration],
          "Result should have correct iteration number"
      end
    end
  end
end
