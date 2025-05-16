# frozen_string_literal: true

require "test_helper"

class RetentionPoliciesTest < Minitest::Test
  def test_base_policy
    policy = Awfy::RetentionPolicies::Base.new

    assert_raises(NoMethodError) do
      policy.retain?(nil)
    end

    assert_equal "base", policy.name
  end

  def test_keep_all_policy
    policy = Awfy::RetentionPolicies::KeepAll.new

    # KeepAll policy should always return true
    assert policy.retain?(nil)
    assert policy.retain?(Object.new)

    # Test with a Result object
    result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_keep_all",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now - 3600 * 24 * 365, # 1 year ago
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(result)
  end

  def test_keep_none_policy
    policy = Awfy::RetentionPolicies::KeepNone.new

    # KeepNone policy should always return false
    refute policy.retain?(nil)
    refute policy.retain?(Object.new)

    # Test with a Result object
    result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_keep_none",
      runtime: Awfy::Runtimes::MRI,
      timestamp: Time.now, # even a fresh result
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    refute policy.retain?(result)
  end

  def test_date_based_policy_default
    # Test with default retention (30 days)
    config = Awfy::Config.new(retention_policy: Awfy::RetentionPolicyAliases::Date)
    policy = config.current_retention_policy

    assert_equal 30, policy.retention_days
    assert_equal "date_based_30_days", policy.name

    # Test with a recent result (should be kept)
    recent_result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_recent_default",
      runtime: "mri",
      timestamp: Time.now - 3600 * 24 * 15, # 15 days ago
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(recent_result)

    # Test with an old result (should be deleted)
    old_result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_old_default",
      runtime: "mri",
      timestamp: Time.now - 3600 * 24 * 60, # 60 days ago
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    refute policy.retain?(old_result)
  end

  def test_date_based_policy_custom_days
    # Test with custom retention (7 days)
    config = Awfy::Config.new(retention_policy: Awfy::RetentionPolicyAliases::Date, retention_days: 7)
    policy = config.current_retention_policy

    assert_equal 7, policy.retention_days
    assert_equal "date_based_7_days", policy.name

    # Test with a result from 5 days ago (should be kept)
    recent_result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_recent_custom",
      runtime: "mri",
      timestamp: Time.now - 3600 * 24 * 5, # 5 days ago
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    assert policy.retain?(recent_result)

    # Test with a result from 10 days ago (should be deleted)
    old_result = Awfy::Result.new(
      type: :ips,
      group_name: "test_group",
      report_name: "test_report",
      test_name: "test_case_old_custom",
      runtime: "mri",
      timestamp: Time.now - 3600 * 24 * 10, # 10 days ago
      branch: "main",
      commit_hash: "test",
      commit_message: "test",
      ruby_version: "3.0.0",
      result_id: "test",
      result_data: {}
    )

    refute policy.retain?(old_result)
  end

  def test_module_functions
    # Test creation via module function
    policy = Awfy::RetentionPolicies.create("keep_all")
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy

    # Test module function aliases
    policy = Awfy::RetentionPolicies.create("none")
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    policy = Awfy::RetentionPolicies.create("keep_none")
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    policy = Awfy::RetentionPolicies.create("keep_all")
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy

    policy = Awfy::RetentionPolicies.create("date_based")
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    policy = Awfy::RetentionPolicies.create("date")
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    # Test convenience methods with explicit config
    policy = Awfy::RetentionPolicies.none
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    policy = Awfy::RetentionPolicies.keep_none
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    policy = Awfy::RetentionPolicies.keep
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy

    policy = Awfy::RetentionPolicies.keep_all
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
  end

  def test_create_function
    # Test default (keep_all) policy
    policy = Awfy::RetentionPolicies.create("keep_all")
    assert_instance_of Awfy::RetentionPolicies::KeepAll, policy

    # Test "none" policy
    policy = Awfy::RetentionPolicies.create("none")
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    # Test "keep_none" policy
    policy = Awfy::RetentionPolicies.create("keep_none")
    assert_instance_of Awfy::RetentionPolicies::KeepNone, policy

    # Test "date" policy
    policy = Awfy::RetentionPolicies.create("date")
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    # Test "date_based" policy
    policy = Awfy::RetentionPolicies.create("date_based")
    assert_instance_of Awfy::RetentionPolicies::DateBased, policy

    # Test "unknown" policy (should raise)
    assert_raises do
      Awfy::RetentionPolicies.create("unknown")
    end
  end
end
