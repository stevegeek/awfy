# frozen_string_literal: true

module Awfy
  Config = Data.define(
    # Display options
    :verbose,         # Boolean: verbose output
    :quiet,           # Boolean: silence output
    :summary,         # Boolean: generate a summary of the results
    :summary_order,   # String: sort order for summary tables - "desc", "asc", "leader"
    :table_format,    # Boolean: display output in table format
    :classic_style,   # Boolean: use classic style instead of modern style
    :ascii_only,      # Boolean: use ASCII characters only (no Unicode)
    :no_color,        # Boolean: don't use colored output
    # Input paths
    :setup_file_path, # String: path to the setup file
    :tests_path,      # String: path to the tests files
    # Comparison options
    :compare_with_branch, # String: name of branch to compare with
    :commit_range,        # String: commit range to compare (e.g., "HEAD~5..HEAD")
    :compare_control,     # Boolean: when comparing branches, also re-run control blocks
    :assert,              # Boolean: assert that results are within thresholds
    # Runtime options
    :runtime,         # String: "both", "yjit", or "mri"
    :test_time,       # Integer: seconds to run IPS benchmarks
    :test_iterations, # Integer: iterations to run tests
    :test_warm_up,    # Integer: seconds to warmup IPS benchmarks
    # Commit range options
    :ignore_commits,  # String: commits to ignore
    :use_cached,      # Boolean: use cached results if available
    :results_only,    # Boolean: only display previously saved results
    # Storage options
    :storage_backend, # String: storage backend for results - "json", "sqlite", or "memory"
    :storage_name,    # String: name for the storage repository (database name or directory)
    # Retention policy options
    :retention_policy, # String: the retention policy to use - "keep_all" or "date_based"
    :retention_days    # Integer: number of days to keep results (used by date_based policy)
  ) do
    # Default values
    def initialize(
      verbose: false,
      quiet: false,
      summary: true,
      summary_order: "leader",
      table_format: false,
      classic_style: false,
      ascii_only: false,
      no_color: false,
      setup_file_path: "./benchmarks/setup",
      tests_path: "./benchmarks/tests",
      compare_with_branch: nil,
      commit_range: nil,
      compare_control: false,
      assert: nil,
      runtime: "both",
      test_time: 3,
      test_iterations: 1_000_000,
      test_warm_up: 1,
      ignore_commits: nil,
      use_cached: true,
      results_only: false,
      storage_backend: DEFAULT_BACKEND,
      storage_name: "benchmark_history",
      retention_policy: "keep_all",
      retention_days: 30
    )
      super
    end

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
  end
end
