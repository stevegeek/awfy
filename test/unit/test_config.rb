# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestConfig < Minitest::Test
    def test_initialize_with_defaults
      config = Config.new

      # Display options defaults
      assert_equal VerbosityLevel::NONE, config.verbose
      assert_equal true, config.summary
      assert_equal "leader", config.summary_order
      assert_equal false, config.list
      assert_equal ColorMode::AUTO, config.color

      # Runner defaults
      assert_equal RunnerTypes::IMMEDIATE, config.runner

      # Input paths defaults
      assert_equal "./benchmarks/setup", config.setup_file_path
      assert_equal "./benchmarks/tests", config.tests_path
      assert_nil config.target_repo_path

      # Comparison options defaults
      assert_nil config.compare_with_branch
      assert_nil config.commit_range
      assert_nil config.control_commit
      assert_equal false, config.compare_control
      assert_equal false, config.assert

      # Runtime options defaults
      assert_equal "both", config.runtime
      assert_equal 3.0, config.test_time
      assert_equal 1_000_000, config.test_iterations
      assert_equal 1.0, config.test_warm_up

      # Commit range options defaults
      assert_nil config.ignore_commits
      assert_equal true, config.use_cached
      assert_equal false, config.results_only

      # Storage options defaults
      assert_equal StoreAliases::JSON, config.storage_backend
      assert_equal "./benchmarks/.awfy_benchmark_results", config.storage_name

      # Retention policy defaults
      assert_equal RetentionPolicyAliases::KeepAll, config.retention_policy
      assert_equal 30, config.retention_days
    end

    def test_verbose_boolean_conversion
      # true converts to BASIC
      config = Config.new(verbose: true)
      assert_equal VerbosityLevel::BASIC, config.verbose

      # false converts to NONE
      config = Config.new(verbose: false)
      assert_equal VerbosityLevel::NONE, config.verbose
    end

    def test_verbose_integer_conversion
      config = Config.new(verbose: 1)
      assert_equal VerbosityLevel::BASIC, config.verbose

      config = Config.new(verbose: 2)
      assert_equal VerbosityLevel::DETAILED, config.verbose

      config = Config.new(verbose: -1)
      assert_equal VerbosityLevel::MUTE, config.verbose
    end

    def test_verbose_level_direct_assignment
      config = Config.new(verbose: VerbosityLevel::DETAILED)
      assert_equal VerbosityLevel::DETAILED, config.verbose
    end

    def test_yjit_only_predicate
      config = Config.new(runtime: "yjit")
      assert config.yjit_only?

      config = Config.new(runtime: "mri")
      refute config.yjit_only?

      config = Config.new(runtime: "both")
      refute config.yjit_only?
    end

    def test_both_runtimes_predicate
      config = Config.new(runtime: "both")
      assert config.both_runtimes?

      config = Config.new(runtime: "yjit")
      refute config.both_runtimes?

      config = Config.new(runtime: "mri")
      refute config.both_runtimes?
    end

    def test_show_summary_predicate
      config = Config.new(summary: true)
      assert config.show_summary?

      config = Config.new(summary: false)
      refute config.show_summary?
    end

    def test_quiet_predicate
      config = Config.new(verbose: VerbosityLevel::MUTE)
      assert config.quiet?

      config = Config.new(verbose: VerbosityLevel::NONE)
      refute config.quiet?

      config = Config.new(verbose: VerbosityLevel::BASIC)
      refute config.quiet?
    end

    def test_verbose_query_with_default_level
      config = Config.new(verbose: VerbosityLevel::BASIC)
      assert config.verbose?

      config = Config.new(verbose: VerbosityLevel::NONE)
      refute config.verbose?
    end

    def test_verbose_query_with_specific_level
      config = Config.new(verbose: VerbosityLevel::DETAILED)
      assert config.verbose?(VerbosityLevel::BASIC)
      assert config.verbose?(VerbosityLevel::DETAILED)
      refute config.verbose?(VerbosityLevel::DEBUG)

      config = Config.new(verbose: VerbosityLevel::NONE)
      refute config.verbose?(VerbosityLevel::BASIC)
    end

    def test_verbose_query_with_integer_level
      config = Config.new(verbose: VerbosityLevel::DETAILED)
      assert config.verbose?(1) # BASIC level
      assert config.verbose?(2) # DETAILED level
      refute config.verbose?(3) # DEBUG level
    end

    def test_assert_predicate
      config = Config.new(assert: true)
      assert config.assert?

      config = Config.new(assert: false)
      refute config.assert?
    end

    def test_compare_control_predicate
      config = Config.new(compare_control: true)
      assert config.compare_control?

      config = Config.new(compare_control: false)
      refute config.compare_control?
    end

    def test_humanized_runtime
      config = Config.new(runtime: "yjit")
      assert_equal "YJIT", config.humanized_runtime

      config = Config.new(runtime: "mri")
      assert_equal "MRI", config.humanized_runtime

      config = Config.new(runtime: "both")
      assert_equal "BOTH", config.humanized_runtime
    end

    def test_color_enabled
      config = Config.new(color: ColorMode::AUTO)
      assert config.color_enabled?

      config = Config.new(color: ColorMode::LIGHT)
      assert config.color_enabled?

      config = Config.new(color: ColorMode::OFF)
      refute config.color_enabled?
    end

    def test_color_off
      config = Config.new(color: ColorMode::OFF)
      assert config.color_off?

      config = Config.new(color: ColorMode::AUTO)
      refute config.color_off?
    end

    def test_color_auto
      config = Config.new(color: ColorMode::AUTO)
      assert config.color_auto?

      config = Config.new(color: ColorMode::OFF)
      refute config.color_auto?
    end

    def test_color_ansi
      config = Config.new(color: ColorMode::ANSI)
      assert config.color_ansi?

      config = Config.new(color: ColorMode::AUTO)
      refute config.color_ansi?
    end

    def test_color_conversion_from_string
      config = Config.new(color: "light")
      assert_equal ColorMode::LIGHT, config.color

      config = Config.new(color: "dark")
      assert_equal ColorMode::DARK, config.color
    end

    def test_runner_conversion_from_string
      config = Config.new(runner: "forked")
      assert_equal RunnerTypes::FORKED, config.runner

      config = Config.new(runner: "spawn")
      assert_equal RunnerTypes::SPAWN, config.runner
    end

    def test_storage_backend_conversion_from_string
      config = Config.new(storage_backend: "sqlite")
      assert_equal StoreAliases::SQLite, config.storage_backend

      config = Config.new(storage_backend: "memory")
      assert_equal StoreAliases::Memory, config.storage_backend
    end

    def test_retention_policy_conversion_from_string
      config = Config.new(retention_policy: "keep_all")
      assert_equal RetentionPolicyAliases::KeepAll, config.retention_policy

      config = Config.new(retention_policy: "date_based")
      assert_equal RetentionPolicyAliases::DateBased, config.retention_policy
    end

    def test_current_retention_policy
      config = Config.new(retention_policy: "keep_all")
      policy = config.current_retention_policy

      assert_instance_of Awfy::RetentionPolicies::KeepAll, policy
    end

    def test_current_retention_policy_with_date_based
      config = Config.new(retention_policy: "date_based", retention_days: 15)
      policy = config.current_retention_policy

      assert_instance_of Awfy::RetentionPolicies::DateBased, policy
      assert_equal 15, policy.retention_days
    end

    def test_test_time_conversion_to_float
      config = Config.new(test_time: 5)
      assert_equal 5.0, config.test_time
      assert_instance_of Float, config.test_time

      config = Config.new(test_time: "3.5")
      assert_equal 3.5, config.test_time
    end

    def test_test_warm_up_conversion_to_float
      config = Config.new(test_warm_up: 2)
      assert_equal 2.0, config.test_warm_up
      assert_instance_of Float, config.test_warm_up
    end

    def test_to_h_converts_enum_values
      config = Config.new(
        color: ColorMode::LIGHT,
        runner: RunnerTypes::FORKED,
        storage_backend: StoreAliases::SQLite,
        retention_policy: RetentionPolicyAliases::DateBased,
        verbose: VerbosityLevel::BASIC
      )

      hash = config.to_h

      assert_equal "light", hash[:color]
      assert_equal "forked", hash[:runner]
      assert_equal "sqlite", hash[:storage_backend]
      assert_equal "date_based", hash[:retention_policy]
      assert_equal 1, hash[:verbose]
    end

    def test_to_h_converts_nilable_string_fields
      config = Config.new(
        compare_with_branch: "main",
        commit_range: "HEAD~5..HEAD",
        ignore_commits: "abc123,def456"
      )

      hash = config.to_h

      assert_equal "main", hash[:compare_with_branch]
      assert_equal "HEAD~5..HEAD", hash[:commit_range]
      assert_equal "abc123,def456", hash[:ignore_commits]
    end

    def test_to_h_includes_all_properties
      config = Config.new(
        compare_with_branch: nil,
        commit_range: nil,
        ignore_commits: nil
      )

      hash = config.to_h

      # All properties are present in the hash, even nil ones
      assert hash.key?(:compare_with_branch)
      assert hash.key?(:commit_range)
      assert hash.key?(:ignore_commits)

      # Values should be nil
      assert_nil hash[:compare_with_branch]
      assert_nil hash[:commit_range]
      assert_nil hash[:ignore_commits]
    end

    def test_custom_paths
      config = Config.new(
        setup_file_path: "/custom/setup",
        tests_path: "/custom/tests",
        target_repo_path: "/custom/repo"
      )

      assert_equal "/custom/setup", config.setup_file_path
      assert_equal "/custom/tests", config.tests_path
      assert_equal "/custom/repo", config.target_repo_path
    end

    def test_comparison_options
      config = Config.new(
        compare_with_branch: "feature",
        commit_range: "HEAD~10..HEAD",
        control_commit: "abc123",
        compare_control: true
      )

      assert_equal "feature", config.compare_with_branch
      assert_equal "HEAD~10..HEAD", config.commit_range
      assert_equal "abc123", config.control_commit
      assert config.compare_control?
    end

    def test_runtime_options
      config = Config.new(
        runtime: "yjit",
        test_time: 5.0,
        test_iterations: 2_000_000,
        test_warm_up: 2.0
      )

      assert_equal "yjit", config.runtime
      assert_equal 5.0, config.test_time
      assert_equal 2_000_000, config.test_iterations
      assert_equal 2.0, config.test_warm_up
    end

    def test_commit_range_options
      config = Config.new(
        ignore_commits: "abc123,def456",
        use_cached: false,
        results_only: true
      )

      assert_equal "abc123,def456", config.ignore_commits
      refute config.use_cached
      assert config.results_only
    end

    def test_storage_options
      config = Config.new(
        storage_backend: "sqlite",
        storage_name: "/custom/db"
      )

      assert_equal StoreAliases::SQLite, config.storage_backend
      assert_equal "/custom/db", config.storage_name
    end
  end
end
