# frozen_string_literal: true

module Awfy
  Options = Data.define(
    # Display options
    :verbose,         # Boolean: verbose output
    :quiet,           # Boolean: silence output
    :summary,         # Boolean: generate a summary of the results
    :summary_order,   # String: sort order for summary tables - "desc", "asc", "leader"
    :table_format,    # Boolean: display output in table format
    # Output options
    :save,            # Boolean: save benchmark results to results directory
    :temp_output_directory, # String: directory to store temporary output files
    :results_directory,     # String: directory to store benchmark results
    # Input paths
    :setup_file_path, # String: path to the setup file
    :tests_path,      # String: path to the tests files
    # Comparison options
    :compare_with_branch, # String: name of branch to compare with
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
    :storage_backend  # String: storage backend for results - "json" or "sqlite"
  ) do
    # Default values
    def initialize(
      verbose: false,
      quiet: false,
      summary: true,
      summary_order: "leader",
      table_format: false,
      save: false,
      temp_output_directory: "./benchmarks/tmp",
      results_directory: "./benchmarks/saved",
      setup_file_path: "./benchmarks/setup",
      tests_path: "./benchmarks/tests",
      compare_with_branch: nil,
      compare_control: false,
      assert: nil,
      runtime: "both",
      test_time: 3,
      test_iterations: 1_000_000,
      test_warm_up: 1,
      ignore_commits: nil,
      use_cached: true,
      results_only: false,
      storage_backend: "json"
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

    def save? = save
  end
end
