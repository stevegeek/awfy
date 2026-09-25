# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class JsonStoreTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @test_dir = Dir.mktmpdir

    # Create storage path
    @storage_dir = File.join(@test_dir, "test_json_store")

    # Create retention policy
    @retention_policy = Awfy::RetentionPolicies.keep_all

    # Create the Json store instance to test
    @store = Awfy::Stores::Json.new(storage_name: @storage_dir, retention_policy: @retention_policy)
  end

  def teardown
    # Clean up the temporary directory
    FileUtils.remove_entry(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_save_result
    # Create test result
    result = Awfy::IPSResult.new(
      type: :ips,
      group_name: "Test Group",
      report_name: "#method_name",
      test_name: "test_case",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now,
      branch: "main",
      commit_hash: "abc123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-1",
      result_data: {
        iterations: 1000,
        runtime: 0.5,
        ips: 2000.0
      }
    )

    # Store the result
    result_path = @store.save_result(result)

    # Assert the result file exists
    assert File.exist?(result_path), "Result file was not created"

    # Verify the stored data matches what we provided
    result_result = JSON.parse(File.read(result_path))
    assert result_result["result_data"], "Result data should be present"
    assert_equal 1000, result_result["result_data"]["iterations"]
    assert_equal 0.5, result_result["result_data"]["runtime"]
    assert_equal 2000.0, result_result["result_data"]["ips"]

    # Verify the result file exists and contains our entry
    result_files = Dir.glob(File.join(@storage_dir, "*#{Awfy::Stores::AWFY_RESULT_EXTENSION}"))
    assert_equal 1, result_files.length, "Expected one result file"

    # Verify result content
    result_content = JSON.parse(File.read(result_files.first))
    assert_equal "Test Group", result_content["group_name"]
    assert_equal "#method_name", result_content["report_name"]
    assert_equal "test_case", result_content["test_name"]
    assert_equal "mri", result_content["runtime"]
    assert_equal "main", result_content["branch"]
    assert_equal "abc123", result_content["commit_hash"]

    # Verify result_id is stored in result
    assert result_content["result_id"], "result_id should be present in result"
    assert result_content["result_data"], "result_data should be present in result"
  end

  def test_save_result_additional
    # Create test result
    result = Awfy::MemoryResult.new(
      type: :memory,
      group_name: "Test Group",
      report_name: "#memory_test",
      test_name: "memory_test_case",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now,
      branch: "main",
      commit_hash: "def456",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-2",
      result_data: {
        memory: 1024,
        objects: 50
      }
    )

    # Store the result
    result_path = @store.save_result(result)

    # Assert the result file exists
    assert File.exist?(result_path), "Result file was not created"
    assert_match(/#{@test_dir}/, result_path, "Result should be in the test directory")

    # Verify result file exists with the right result_id
    result_file = File.join(@storage_dir, "#{result.result_id}#{Awfy::Stores::AWFY_RESULT_EXTENSION}")
    assert File.exist?(result_file), "Expected result file to exist in results directory"
  end

  def test_query_results
    # Store multiple results first
    timestamp = Time.now

    # Store result 1
    result1 = Awfy::IPSResult.new(
      type: :ips,
      group_name: "Query Group",
      report_name: "#method1",
      test_name: "test1",
      runtime: Awfy::Runtimes::MRI,
      timestamp: timestamp,
      branch: "main",
      commit_hash: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-3",
      result_data: {ips: 1000.0}
    )

    @store.save_result(result1)

    # Store result 2 with different runtime
    result2 = Awfy::IPSResult.new(
      type: :ips,
      group_name: "Query Group",
      report_name: "#method1",
      test_name: "test2",
      runtime: Awfy::Runtimes::YJIT,
      timestamp: timestamp,
      branch: "main",
      commit_hash: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-4",
      result_data: {ips: 1500.0}
    )

    @store.save_result(result2)

    # Store result 3 with different group
    result3 = Awfy::IPSResult.new(
      type: :ips,
      group_name: "Another Group",
      report_name: "#method2",
      test_name: "test3",
      runtime: Awfy::Runtimes::MRI,
      timestamp: timestamp,
      branch: "main",
      commit_hash: "query1",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-5",
      result_data: {ips: 2000.0}
    )

    @store.save_result(result3)

    assert_equal %w[test-3 test-4 test-5], @store.query_results(type: :ips).map(&:result_id).sort
    assert_empty @store.query_results(type: :memory)

    assert_equal %w[test-3 test-4], @store.query_results(type: :ips, group_name: "Query Group").map(&:result_id).sort

    runtime_results = @store.query_results(type: :ips, runtime: "yjit")
    assert_equal ["test-4"], runtime_results.map(&:result_id)
    assert_equal 1500.0, runtime_results.first.result_data[:ips]

    combo_results = @store.query_results(type: :ips, group_name: "Query Group", report_name: "#method1", runtime: "mri")
    assert_equal ["test-3"], combo_results.map(&:result_id)
    assert_equal 1000.0, combo_results.first.result_data[:ips]
  end

  def test_save_and_query_measure_results_by_label
    base = measure_result("base-1", label: "base", wall_s: 1.0)
    candidate = measure_result("candidate-1", label: "candidate", wall_s: 2.0)
    [base, candidate].each { @store.save_result(it) }

    found = @store.query_results(type: :measure, label: "candidate")
    assert_equal ["candidate-1"], found.map(&:result_id)
    assert_instance_of Awfy::MeasureResult, found.first
    assert_equal "candidate", found.first.run_label
    assert_equal({"wall_s" => 2.0}, found.first.result_data[:collectors]["timing"])

    assert_equal %w[base-1 candidate-1], @store.query_results(type: :measure).map(&:result_id).sort
    assert_equal ["base-1"], @store.query_results(type: :measure, label: "base", test_name: "t").map(&:result_id)
    assert_empty @store.query_results(type: :measure, label: "missing")
    assert_empty @store.query_results(type: :ips, label: "base")
  end

  def test_save_result_refuses_a_duplicate_result_id
    @store.save_result(measure_result("dup-1", label: "base", wall_s: 1.0))
    assert_raises(RuntimeError) { @store.save_result(measure_result("dup-1", label: "base", wall_s: 1.0)) }
  end

  def measure_result(result_id, label:, wall_s:)
    Awfy::MeasureResult.new(type: :measure, group_name: "G", report_name: "R", test_name: "t",
      runtime: "mri", timestamp: Time.now, result_id: result_id, run_label: label,
      result_data: {collectors: {"timing" => {"wall_s" => wall_s}}})
  end

  def test_load_result
    # Store a result to load later
    result = Awfy::IPSResult.new(
      type: :ips,
      group_name: "Load Test",
      report_name: "#load_method",
      test_name: "load_test_case",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now,
      branch: "main",
      commit_hash: "load123",
      commit_message: "Test commit",
      ruby_version: "3.1.0",
      result_id: "test-6",
      result_data: {ips: 3000.0, iterations: 5000}
    )

    result_path = @store.save_result(result)

    # Read the file to get the result with result_id
    result_content = JSON.parse(File.read(result_path))
    result_id = result_content["result_id"]

    # Load the result by ID
    loaded_result = @store.load_result(result_id)

    # Verify loaded result is a Result object
    assert_instance_of Awfy::IPSResult, loaded_result

    # Verify loaded data matches original
    assert_equal 3000.0, loaded_result.result_data[:ips]
    assert_equal 5000, loaded_result.result_data[:iterations]
  end

  def create_test_result_file(days_ago = 0)
    # Create test files in the storage directory
    FileUtils.mkdir_p(@storage_dir)
    test_file = File.join(@storage_dir, "test-results-#{days_ago.to_i}-#{SecureRandom.hex(3)}-#{Awfy::Stores::AWFY_RESULT_EXTENSION}")
    # Create a valid result with proper Result object
    test_result = Awfy::IPSResult.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_clean_#{days_ago}",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now - (days_ago * 24 * 60 * 60),
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test-results-#{days_ago.to_i}-#{SecureRandom.hex(3)}",
      result_data: {test: "results"}
    )

    File.write(test_file, JSON.dump(test_result.serialize))

    # Verify file exists before cleaning
    assert File.exist?(test_file), "Test file should exist"

    test_file
  end

  def test_clean_results
    test_file = create_test_result_file

    # Clean results with default parameters (KeepAll policy shouldn't delete anything)
    @store.clean_results

    # Verify file still exists (with KeepAll retention policy, everything is kept)
    assert File.exist?(test_file), "Test file should still exist with KeepAll retention policy"

    # Now create a store with KeepNone policy which should delete everything
    keep_none_policy = Awfy::RetentionPolicies.keep_none
    keep_none_store = Awfy::Stores::Json.new(storage_name: @storage_dir, retention_policy: keep_none_policy)

    assert keep_none_policy.is_a?(Awfy::RetentionPolicies::KeepNone), "Should be a KeepNone policy"

    # Clean with KeepNone retention policy
    keep_none_store.clean_results

    # Verify file is deleted
    refute File.exist?(test_file), "Test file should be deleted with KeepNone retention policy"
  end

  def test_clean_results_with_date_based_policy
    # Create DateBased retention policy (7 days)
    date_policy = Awfy::RetentionPolicies.create("date_based", retention_days: 7)
    store = Awfy::Stores::Json.new(storage_name: @storage_dir, retention_policy: date_policy)

    assert date_policy.is_a?(Awfy::RetentionPolicies::DateBased), "Should be a DateBased policy"

    # 1. Recent file (3 days ago) - should be kept
    test_file_1 = create_test_result_file(3)

    # 2. Old file (14 days ago) - should be deleted
    test_file_2 = create_test_result_file(14)

    # Verify files exist before cleaning
    assert File.exist?(test_file_1), "Recent file should exist"
    assert File.exist?(test_file_2), "Old file should exist"

    # Clean results with date-based policy
    store.clean_results

    # Test passes automatically now that we've fixed the date-based retention policy

    # Verify recent file still exists but old file is deleted
    assert File.exist?(test_file_1), "Recent file should still exist (within retention period)"
    refute File.exist?(test_file_2), "Old file should be deleted (outside retention period)"
  end

  def test_clean_results_with_keep_all_policy
    # Create KeepAll retention policy
    keep_all_policy = Awfy::RetentionPolicies.keep_all
    store = Awfy::Stores::Json.new(storage_name: @storage_dir, retention_policy: keep_all_policy)

    test_file = create_test_result_file(3)

    # Verify file exists before cleaning
    assert File.exist?(test_file), "Test file should exist"

    # Clean results with default parameters (should keep everything with keep_all policy)
    store.clean_results

    # Verify file still exists
    assert File.exist?(test_file), "Test file should still exist with keep_all retention policy"
  end
end
