# frozen_string_literal: true

module Awfy
  class Config < Literal::Data
    # Display options
    prop :verbose, _Boolean, default: false         # verbose output
    prop :quiet, _Boolean, default: false           # silence output
    prop :summary, _Boolean, default: true          # generate a summary of the results
    prop :summary_order, String, default: "leader" # sort order for summary tables - "desc", "asc", "leader"
    prop :table_format, _Boolean, default: false    # display output in table format
    prop :classic_style, _Boolean, default: false   # use classic style instead of modern style
    prop :ascii_only, _Boolean, default: false      # use ASCII characters only (no Unicode)
    prop :no_color, _Boolean, default: false        # don't use colored output

    # Input paths
    prop :setup_file_path, String, default: "./benchmarks/setup" # path to the setup file
    prop :tests_path, String, default: "./benchmarks/tests"      # path to the tests files

    # Comparison options
    prop :compare_with_branch, _Nilable(String)                  # name of branch to compare with
    prop :commit_range, _Nilable(String)                         # commit range to compare (e.g., "HEAD~5..HEAD")
    prop :compare_control, _Boolean, default: false      # when comparing branches, also re-run control blocks
    prop :assert, _Boolean, default: false               # assert that results are within thresholds

    # Runtime options
    prop :runtime, String, default: "both"              # "both", "yjit", or "mri"
    prop :test_time, Integer, default: 3                # Integer: seconds to run IPS benchmarks
    prop :test_iterations, Integer, default: 1_000_000  # Integer: iterations to run tests
    prop :test_warm_up, Integer, default: 1             # Integer: seconds to warmup IPS benchmarks

    # Commit range options
    prop :ignore_commits, _Nilable(String)          # commits to ignore
    prop :use_cached, _Boolean, default: true            # use cached results if available
    prop :results_only, _Boolean, default: false         # only display previously saved results

    # Storage options
    prop :storage_backend, String, default: -> { DEFAULT_BACKEND }  # storage backend for results - "json", "sqlite", or "memory"
    prop :storage_name, String, default: "benchmark_history"        # name for the storage repository (database name or directory)

    # Retention policy options
    prop :retention_policy, RetentionPolicyAliases, default: RetentionPolicyAliases::KeepAll, &RetentionPolicyAliases
    prop :retention_days, Integer, default: 30           # Integer: number of days to keep results (used by date_based policy)

    def yjit_only? = runtime == "yjit"

    def both_runtimes? = runtime == "both"

    def show_summary? = summary

    def quiet? = quiet

    def verbose? = verbose

    def assert? = assert

    def compare_control? = compare_control

    def humanized_runtime = runtime.upcase

    def classic_style? = classic_style

    def ascii_only? = ascii_only

    def no_color? = no_color

    def current_retention_policy
      retention_policy_options = {
        retention_days: retention_days
      }.compact
      Awfy::RetentionPolicies.create(retention_policy, **retention_policy_options)
    end
  end
end
