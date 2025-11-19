# frozen_string_literal: true

module Awfy
  class Config < Literal::Data
    # Display options

    # verbose output level
    prop :verbose, VerbosityLevel, default: VerbosityLevel::NONE do |value|
      if value == true
        VerbosityLevel::BASIC
      elsif value == false
        VerbosityLevel::NONE
      elsif value.is_a?(Integer)
        VerbosityLevel[value]
      elsif value.is_a?(VerbosityLevel)
        value
      else
        raise ArgumentError, "Invalid value for verbose: #{value.inspect}"
      end
    end

    # generate a summary of the results
    prop :summary, _Boolean, default: true
    # sort order for summary tables - "desc", "asc", "leader"
    prop :summary_order, String, default: "leader"
    # display output in list instead of table format
    prop :list, _Boolean, default: false
    # color mode: auto, light, dark, off, ansi
    prop :color, ColorMode, default: ColorMode::AUTO, &ColorMode

    # Runner options

    # type of runner - "immediate", "forked", "spawn", "thread"
    # This can be a string or a RunnerTypes enum value
    prop :runner, RunnerTypes, default: RunnerTypes::IMMEDIATE, &RunnerTypes

    # Input paths

    # path to the setup file
    prop :setup_file_path, String, default: "./benchmarks/setup"
    # path to the tests files
    prop :tests_path, String, default: "./benchmarks/tests"
    # path to the git repository for commit checkouts (defaults to current directory)
    prop :target_repo_path, _Nilable(String)

    # Comparison options

    # name of branch to compare with
    prop :compare_with_branch, _Nilable(String)
    # commit range to compare (e.g., "HEAD~5..HEAD")
    prop :commit_range, _Nilable(String)
    # commit to use as control/baseline for comparisons (defaults to first commit in range)
    prop :control_commit, _Nilable(String)
    # when comparing branches, also re-run control blocks
    prop :compare_control, _Boolean, default: false
    # assert that results are within thresholds
    prop :assert, _Boolean, default: false

    # Runtime options

    # "both", "yjit", or "mri"
    prop :runtime, String, default: "both"
    # seconds to run IPS benchmarks
    prop :test_time, Float, default: 3.0, &:to_f
    # iterations to run tests
    prop :test_iterations, Integer, default: 1_000_000
    # seconds to warmup IPS benchmarks
    prop :test_warm_up, Float, default: 1.0, &:to_f

    # Commit range options

    # commits to ignore
    prop :ignore_commits, _Nilable(String)
    # use cached results if available
    prop :use_cached, _Boolean, default: true
    # only display previously saved results
    prop :results_only, _Boolean, default: false

    # Storage options

    # current storage backend
    prop :storage_backend, StoreAliases, default: StoreAliases::JSON, &StoreAliases
    # name for the storage repository (database name or directory)
    prop :storage_name, String, default: "./benchmarks/.awfy_benchmark_results"

    # Retention policy options

    # the retention policy to use
    prop :retention_policy, RetentionPolicyAliases, default: RetentionPolicyAliases::KeepAll, &RetentionPolicyAliases
    # If policy is date based, then this is the number of days to keep results
    prop :retention_days, Integer, default: 30

    def yjit_only? = runtime == "yjit"

    def both_runtimes? = runtime == "both"

    def show_summary? = summary

    def quiet?
      verbose == VerbosityLevel::MUTE
    end

    def verbose?(level = VerbosityLevel::BASIC)
      level_enum = VerbosityLevel[level] || level
      verbose.value >= level_enum.value
    end

    def assert? = assert

    def compare_control? = compare_control

    def humanized_runtime = runtime.upcase

    def color_enabled?
      color != ColorMode::OFF
    end

    def color_off?
      color == ColorMode::OFF
    end

    def color_auto?
      color == ColorMode::AUTO
    end

    def color_ansi?
      color == ColorMode::ANSI
    end

    def current_retention_policy
      Awfy::RetentionPolicies.create(retention_policy, retention_days: retention_days)
    end

    def to_h
      super.tap do |hash|
        hash[:color] = color.value
        hash[:runner] = runner.value
        hash[:storage_backend] = storage_backend.value
        hash[:retention_policy] = retention_policy.value
        hash[:verbose] = verbose.value
        hash[:compare_with_branch] = compare_with_branch.to_s if compare_with_branch
        hash[:commit_range] = commit_range.to_s if commit_range
        hash[:ignore_commits] = ignore_commits.to_s if ignore_commits
      end
    end
  end
end
