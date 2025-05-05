# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class JsonResultStoreDatePolicyTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment

    # Create specific directories for this test
    @temp_dir = File.join(@test_dir, "temp_results")
    @results_dir = File.join(@test_dir, "saved_results")
    FileUtils.mkdir_p(@temp_dir)
    FileUtils.mkdir_p(@results_dir)
  end

  def teardown
    teardown_test_environment
  end

  def test_clean_results_with_date_based_policy
    # Create options with DateBased retention policy (7 days)
    options = Awfy::Options.new(
      temp_output_directory: @temp_dir,
      results_directory: @results_dir,
      retention_policy: "date_based",
      retention_days: 7,
      storage_name: "test_date_policy"
    )

    # Create the store
    store = Awfy::Stores::Json.new(options)

    # Create test files
    storage_dir = store.instance_variable_get(:@storage_dir)

    # 1. Recent file (3 days ago) - should be kept
    recent_file = File.join(storage_dir, "recent.json")
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
    old_file = File.join(storage_dir, "old.json")
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
    # Create options with KeepAll retention policy
    options = Awfy::Options.new(
      temp_output_directory: @temp_dir,
      results_directory: @results_dir,
      retention_policy: "keep_all",
      storage_name: "test_keep_all"
    )

    # Create the store
    store = Awfy::Stores::Json.new(options)

    # Create a test file
    storage_dir = store.instance_variable_get(:@storage_dir)
    test_file = File.join(storage_dir, "test_file.json")

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

    File.write(test_file, JSON.dump([metadata]))

    # Verify file exists before cleaning
    assert File.exist?(test_file), "Test file should exist"

    # Clean results with default parameters (should keep everything with keep_all policy)
    store.clean_results

    # Verify file still exists
    assert File.exist?(test_file), "Test file should still exist with keep_all retention policy"
  end
end
