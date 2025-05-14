# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "ostruct"
require "thor"

# Helper module with common test utilities for runner tests
module RunnerTestHelpers
  # Create a mock suite with groups for testing
  def create_mock_suite
    # Create a test with a noop block
    test1 = Awfy::Suites::Test.new(
      name: "test1",
      block: proc { "test result" }
    )

    # Create a report with the test
    test_report = Awfy::Suites::Report.new(
      name: "test_report",
      tests: [test1]
    )

    # Create a group with the report
    test_group = Awfy::Suites::Group.new(
      name: "test_group",
      reports: [test_report]
    )

    # Pass groups as an array to match the Suite's initializer
    Awfy::Suite.new([test_group])
  end

  # Create options for testing with temporary directories
  def create_test_options(test_dir)
    # Calculate paths for test directories
    results_dir = test_dir ? File.join(test_dir, "test_bench_results") : nil

    Awfy::Config.new(
      verbose: false,
      runner: Awfy::RunnerTypes::IMMEDIATE,
      runtime: "ruby",
      test_time: 1.0,
      test_warm_up: 0.5,
      compare_with_branch: nil,
      setup_file_path: "test/fixtures/benchmarks/setup.rb",
      tests_path: "test/fixtures/benchmarks/tests",
      storage_name: results_dir || "./benchmarks/.awfy_benchmark_results",
      commit_range: nil,
      classic_style: false,
      ascii_only: false,
      no_color: false,
      assert: false
    )
  end

  # Create test session with shell and config
  def create_test_session(config)
    # Create a memory store with a keep_all retention policy
    retention_policy = Awfy::RetentionPolicies.keep_all
    results_store = Awfy::Stores::Memory.new(
      storage_name: "test_memory_store",
      retention_policy: retention_policy
    )

    # Create a git client
    git_client = Awfy::GitClient.new(path: Dir.pwd)

    # Create a session with the shell, config, git_client, and results_store
    Awfy::Session.new(
      shell: Awfy::Shell.new(config: config),
      config: config,
      git_client: git_client,
      results_store: results_store
    )
  end
end
