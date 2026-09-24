# frozen_string_literal: true

require "test_helper"

module Awfy
  module RetentionPolicies
    class TestRetentionPolicies < Minitest::Test
      def create_mock_result(timestamp: Time.now)
        Result.new(
          type: :ips,
          baseline: true,
          control: false,
          group_name: "test_group",
          report_name: "test_report",
          test_name: "test1",
          runtime: "mri",
          timestamp: timestamp,
          branch: "main",
          commit_hash: "abc123",
          commit_message: "Test commit",
          result_data: {measured_us: 1000.0, iter: 100, samples: [10.0], cycles: 10}
        )
      end

      # Factory method tests
      def test_create_keep_all
        policy = RetentionPolicies.create("keep_all")
        assert_instance_of KeepAll, policy
      end

      def test_create_keep
        policy = RetentionPolicies.create("keep")
        assert_instance_of KeepAll, policy
      end

      def test_create_keep_none
        policy = RetentionPolicies.create("keep_none")
        assert_instance_of KeepNone, policy
      end

      def test_create_none
        policy = RetentionPolicies.create("none")
        assert_instance_of KeepNone, policy
      end

      def test_create_date_based
        policy = RetentionPolicies.create("date_based", retention_days: 7)
        assert_instance_of DateBased, policy
        assert_equal 7, policy.retention_days
      end

      def test_create_date
        policy = RetentionPolicies.create("date", retention_days: 14)
        assert_instance_of DateBased, policy
        assert_equal 14, policy.retention_days
      end

      def test_create_unknown_raises
        assert_raises(RuntimeError) do
          RetentionPolicies.create("unknown_policy")
        end
      end

      # Helper method tests
      def test_keep_all_helper
        policy = RetentionPolicies.keep_all
        assert_instance_of KeepAll, policy
      end

      def test_keep_helper
        policy = RetentionPolicies.keep
        assert_instance_of KeepAll, policy
      end

      def test_keep_none_helper
        policy = RetentionPolicies.keep_none
        assert_instance_of KeepNone, policy
      end

      def test_none_helper
        policy = RetentionPolicies.none
        assert_instance_of KeepNone, policy
      end

      def test_date_based_helper
        policy = RetentionPolicies.date_based(retention_days: 5)
        assert_instance_of DateBased, policy
        assert_equal 5, policy.retention_days
      end

      def test_date_helper
        policy = RetentionPolicies.date(retention_days: 10)
        assert_instance_of DateBased, policy
        assert_equal 10, policy.retention_days
      end

      # KeepAll tests
      def test_keep_all_retains_all_results
        policy = KeepAll.new
        result = create_mock_result

        assert policy.retain?(result)
      end

      def test_keep_all_retains_old_results
        policy = KeepAll.new
        old_result = create_mock_result(timestamp: Time.now - (365 * 24 * 60 * 60))

        assert policy.retain?(old_result)
      end

      def test_keep_all_name
        policy = KeepAll.new
        assert_equal "keep_all", policy.name
      end

      # KeepNone tests
      def test_keep_none_retains_nothing
        policy = KeepNone.new
        result = create_mock_result

        refute policy.retain?(result)
      end

      def test_keep_none_even_rejects_new_results
        policy = KeepNone.new
        new_result = create_mock_result(timestamp: Time.now)

        refute policy.retain?(new_result)
      end

      def test_keep_none_name
        policy = KeepNone.new
        assert_equal "keep_none", policy.name
      end

      # DateBased tests
      def test_date_based_default_retention
        policy = DateBased.new
        assert_equal 30, policy.retention_days
      end

      def test_date_based_custom_retention
        policy = DateBased.new(retention_days: 7)
        assert_equal 7, policy.retention_days
      end

      def test_date_based_retains_recent_results
        policy = DateBased.new(retention_days: 7)
        recent_result = create_mock_result(timestamp: Time.now - (3 * 24 * 60 * 60))  # 3 days ago

        assert policy.retain?(recent_result)
      end

      def test_date_based_removes_old_results
        policy = DateBased.new(retention_days: 7)
        old_result = create_mock_result(timestamp: Time.now - (10 * 24 * 60 * 60))  # 10 days ago

        refute policy.retain?(old_result)
      end

      def test_date_based_retains_result_at_boundary
        policy = DateBased.new(retention_days: 7)
        # Result just inside the boundary (6.9 days ago)
        boundary_result = create_mock_result(timestamp: Time.now - (6.9 * 24 * 60 * 60))

        assert policy.retain?(boundary_result)
      end

      def test_date_based_removes_result_at_boundary
        policy = DateBased.new(retention_days: 7)
        # Result just outside the boundary (7.1 days ago)
        boundary_result = create_mock_result(timestamp: Time.now - (7.1 * 24 * 60 * 60))

        refute policy.retain?(boundary_result)
      end

      def test_date_based_name_includes_days
        policy = DateBased.new(retention_days: 14)
        assert_equal "date_based_14_days", policy.name
      end

      # Base class tests
      def test_base_retain_raises_not_implemented
        policy = Base.new

        assert_raises(NoMethodError) do
          policy.retain?(create_mock_result)
        end
      end

      def test_base_name_returns_snake_case
        policy = Base.new
        assert_equal "base", policy.name
      end

      # All policies inherit from Base
      def test_keep_all_inherits_from_base
        assert_kind_of Base, KeepAll.new
      end

      def test_keep_none_inherits_from_base
        assert_kind_of Base, KeepNone.new
      end

      def test_date_based_inherits_from_base
        assert_kind_of Base, DateBased.new
      end
    end
  end
end
