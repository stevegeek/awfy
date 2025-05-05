# frozen_string_literal: true

require "test_helper"

class RetentionPoliciesTest < Minitest::Test
  def test_base_policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicies::Base.new(options)

    assert_raises(NotImplementedError) do
      policy.retain?(nil)
    end

    assert_equal "base", policy.name
  end

  def test_keep_all_policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicies::KeepAll.new(options)

    # KeepAll policy should always return true
    assert policy.retain?(nil)
    assert policy.retain?(Object.new)

    # Test with a Result object
    result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i - 3600 * 24 * 365, # 1 year ago
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(result)
  end
  
  def test_keep_none_policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicies::KeepNone.new(options)
    
    # KeepNone policy should always return false
    refute policy.retain?(nil)
    refute policy.retain?(Object.new)
    
    # Test with a Result object
    result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i, # even a fresh result
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )
    
    refute policy.retain?(result)
  end

  def test_date_based_policy_default
    # Test with default retention (30 days)
    options = Awfy::Options.new(retention_policy: "date_based")
    policy = Awfy::RetentionPolicies::DateBased.new(options)

    assert_equal 30, policy.retention_days
    assert_equal "date_based_30_days", policy.name

    # Test with a recent result (should be kept)
    recent_result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i - 3600 * 24 * 15, # 15 days ago
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(recent_result)

    # Test with an old result (should be deleted)
    old_result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i - 3600 * 24 * 60, # 60 days ago
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    refute policy.retain?(old_result)
  end

  def test_date_based_policy_custom_days
    # Test with custom retention (7 days)
    options = Awfy::Options.new(retention_policy: "date_based", retention_days: 7)
    policy = Awfy::RetentionPolicies::DateBased.new(options)

    assert_equal 7, policy.retention_days
    assert_equal "date_based_7_days", policy.name

    # Test with a result from 5 days ago (should be kept)
    recent_result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i - 3600 * 24 * 5, # 5 days ago
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(recent_result)

    # Test with a result from 10 days ago (should be deleted)
    old_result = Awfy::Result.new(
      type: :test,
      group: "test_group",
      report: "test_report",
      runtime: "ruby",
      timestamp: Time.now.to_i - 3600 * 24 * 10, # 10 days ago
      branch: "main",
      commit: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    refute policy.retain?(old_result)
  end

  def test_module_functions
    # Create an Options instance for testing
    options = Awfy::Options.new
    
    # Test creation via module function with explicit options
    policy = Awfy::RetentionPolicies.create("keep_all", options)
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
    
    # Test module function aliases
    policy = Awfy::RetentionPolicies.create("none", options)
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy
    
    policy = Awfy::RetentionPolicies.create("keep_none", options)
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy
    
    policy = Awfy::RetentionPolicies.create("keep_all", options)
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
    
    policy = Awfy::RetentionPolicies.create("date_based", options)
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy
    
    policy = Awfy::RetentionPolicies.create("date", options)
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy
    
    # Test convenience methods with explicit options
    policy = Awfy::RetentionPolicies.none()
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy
    
    policy = Awfy::RetentionPolicies.keep_none()
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy
    
    policy = Awfy::RetentionPolicies.keep()
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
    
    policy = Awfy::RetentionPolicies.keep_all()
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
  end
  
  def test_create_function
    # Test default policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy

    # Test "none" policy
    options = Awfy::Options.new(retention_policy: "none")
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy
    
    # Test "keep_none" policy
    options = Awfy::Options.new(retention_policy: "keep_none")
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    # Test "date" policy
    options = Awfy::Options.new(retention_policy: "date")
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    # Test "date_based" policy
    options = Awfy::Options.new(retention_policy: "date_based")
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    # Test "unknown" policy (should default to keep_all)
    options = Awfy::Options.new(retention_policy: "unknown")
    policy = Awfy::RetentionPolicies.create(options.retention_policy, options)
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
  end
end