# frozen_string_literal: true

require "test_helper"

class RetentionPolicyTest < Minitest::Test
  def test_base_policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicy::Base.new(options)

    assert_raises(NotImplementedError) do
      policy.retain?(nil)
    end

    assert_equal "base", policy.name
  end

  def test_keep_all_policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicy::KeepAll.new(options)

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
    assert_equal "keep_all", policy.name
  end

  def test_date_based_policy_default
    # Test with default retention (30 days)
    options = Awfy::Options.new(retention_policy: "date_based")
    policy = Awfy::RetentionPolicy::DateBased.new(options)

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
    policy = Awfy::RetentionPolicy::DateBased.new(options)

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

  def test_factory
    # Test default policy
    options = Awfy::Options.new
    policy = Awfy::RetentionPolicy::Factory.create(options)
    assert_instance_of Awfy::RetentionPolicy::KeepAll, policy

    # Test "date" policy
    options = Awfy::Options.new(retention_policy: "date")
    policy = Awfy::RetentionPolicy::Factory.create(options)
    assert_instance_of Awfy::RetentionPolicy::DateBased, policy

    # Test "date_based" policy
    options = Awfy::Options.new(retention_policy: "date_based")
    policy = Awfy::RetentionPolicy::Factory.create(options)
    assert_instance_of Awfy::RetentionPolicy::DateBased, policy

    # Test "unknown" policy (should default to keep_all)
    options = Awfy::Options.new(retention_policy: "unknown")
    policy = Awfy::RetentionPolicy::Factory.create(options)
    assert_instance_of Awfy::RetentionPolicy::KeepAll, policy
  end
end
