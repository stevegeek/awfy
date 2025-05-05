# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class JsonStoreDatePolicyTest < Minitest::Test
  def setup
    # Create a temporary directory for testing
    @test_dir = Dir.mktmpdir
  end

  def teardown
    # Clean up the temporary directory
    FileUtils.remove_entry(@test_dir) if Dir.exist?(@test_dir)
  end

  def test_clean_results_with_date_based_policy
    # Create DateBased retention policy (7 days)
    date_options = Awfy::Options.new(retention_days: 7)
    date_policy = Awfy::RetentionPolicies.create("date_based", date_options)

    # Create storage path
    storage_path = File.join(@test_dir, "test_date_policy")
  
    # Create the store
    store = Awfy::Stores::Json.new(storage_path, date_policy)

    # Create test files
    # Ensure directory exists
    FileUtils.mkdir_p(storage_path)

    # 1. Recent file (3 days ago) - should be kept
    recent_file = File.join(storage_path, "recent#{Awfy::Stores::AWFY_RESULT_EXTENSION}")
    recent_metadata = {
      "type" => "test",
      "group" => "test_group",
      "report" => "test_report",
      "runtime" => "ruby",
      "timestamp" => Time.now.to_i - 3600 * 24 * 3, # 3 days ago
      "branch" => "main",
      "result_id" => "recent_id"
    }
    File.write(recent_file, JSON.dump([recent_metadata]))

    # 2. Old file (14 days ago) - should be deleted
    old_file = File.join(storage_path, "old#{Awfy::Stores::AWFY_RESULT_EXTENSION}")
    old_metadata = {
      "type" => "test",
      "group" => "test_group",
      "report" => "test_report",
      "runtime" => "ruby",
      "timestamp" => Time.now.to_i - 3600 * 24 * 14, # 14 days ago
      "branch" => "main",
      "result_id" => "old_id"
    }
    File.write(old_file, JSON.dump([old_metadata]))

    # Verify files exist before cleaning
    assert File.exist?(recent_file), "Recent file should exist"
    assert File.exist?(old_file), "Old file should exist"

    # Clean results with date-based policy
    store.clean_results

    # Verify recent file still exists but old file is deleted
    assert File.exist?(recent_file), "Recent file should still exist (within retention period)"
    refute File.exist?(old_file), "Old file should be deleted (outside retention period)"
  end

  def test_clean_results_with_keep_all_policy
    # Create KeepAll retention policy
    keep_all_policy = Awfy::RetentionPolicies.keep_all

    # Create storage path
    storage_path = File.join(@test_dir, "test_keep_all")
  
    # Create the store
    store = Awfy::Stores::Json.new(storage_path, keep_all_policy)

    # Create a test file
    test_file = File.join(storage_path, "test_file#{Awfy::Stores::AWFY_RESULT_EXTENSION}")

    # Create a valid JSON metadata file with a timestamp
    metadata = {
      "type" => "test",
      "group" => "test_group",
      "report" => "test_report",
      "runtime" => "ruby",
      "timestamp" => Time.now.to_i - 3600 * 24 * 365, # 1 year ago
      "branch" => "main",
      "result_id" => "test_id"
    }

    # Ensure storage directory exists
    FileUtils.mkdir_p(storage_path)
    File.write(test_file, JSON.dump([metadata]))

    # Verify file exists before cleaning
    assert File.exist?(test_file), "Test file should exist"

    # Clean results with default parameters (should keep everything with keep_all policy)
    store.clean_results

    # Verify file still exists
    assert File.exist?(test_file), "Test file should still exist with keep_all retention policy"
  end
end