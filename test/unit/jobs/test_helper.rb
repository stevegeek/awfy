# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

# Helper module with common test utilities for job tests
module JobTestHelpers
  # Create a mock benchmarker for testing
  def create_mock_benchmarker(session)
    MockBenchmarker.new(session: session)
  end

  # Create a mock results manager for testing
  def create_mock_results_manager(session)
    MockResultsManager.new(session: session)
  end

  # Create a test group with reports and tests
  def create_test_group(name: "test_group", with_control: true, with_baseline: true)
    tests = []

    tests << Awfy::Suites::Test.new(
      name: "test1",
      block: proc { "test result" }
    )

    if with_control
      tests << Awfy::Suites::ControlTest.new(
        name: "control_test",
        block: proc { "control result" }
      )
    end

    if with_baseline
      tests << Awfy::Suites::BaselineTest.new(
        name: "baseline_test",
        block: proc { "baseline result" }
      )
    end

    report = Awfy::Suites::Report.new(
      name: "test_report",
      tests: tests
    )

    Awfy::Suites::Group.new(
      name: name,
      reports: [report]
    )
  end

  # Create test config
  def create_test_config
    Awfy::Config.new(
      verbose: false,
      runner: Awfy::RunnerTypes::IMMEDIATE,
      runtime: "mri",
      test_time: 0.1,
      test_warm_up: 0.05,
      compare_with_branch: nil,
      setup_file_path: "test/fixtures/benchmarks/setup.rb",
      tests_path: "test/fixtures/benchmarks/tests",
      storage_name: "./benchmarks/.awfy_benchmark_results",
      commit_range: nil,
      color: Awfy::ColorMode::OFF,
      assert: false,
      summary: false
    )
  end

  # Create test session
  def create_test_session(config)
    retention_policy = Awfy::RetentionPolicies.keep_all
    results_store = Awfy::Stores::Memory.new(
      storage_name: "test_memory_store",
      retention_policy: retention_policy
    )

    git_client = Awfy::GitClient.new(path: Dir.pwd)

    Awfy::Session.new(
      shell: Awfy::Shell.new(config: config),
      config: config,
      git_client: git_client,
      results_store: results_store
    )
  end
end

# Mock Benchmarker for testing jobs
class MockBenchmarker < Literal::Object
  include Awfy::HasSession

  attr_reader :run_calls, :run_tests_calls

  def after_initialize
    @run_calls = []
    @run_tests_calls = []
  end

  def run(group, report_name, &block)
    @run_calls << {group: group, report_name: report_name}
    # Simulate running with the first report
    reports = report_name ? group.reports.select { |r| r.name == report_name } : group.reports
    reports.each do |report|
      yield report, "mri" if block_given?
    end
  end

  def run_group(group, report_name, runtime, include_control = true, &block)
    reports = report_name ? group.reports.select { |r| r.name == report_name } : group.reports
    reports.each do |report|
      yield report, runtime if block_given?
    end
  end

  def run_tests(report, test_name, output: true, &block)
    @run_tests_calls << {report: report, test_name: test_name, output: output}
    tests = test_name ? report.tests.select { |t| t.name == test_name } : report.tests
    tests.each do |test|
      yield test, 1 if block_given?
    end
  end
end

# Mock ResultsManager for testing jobs
class MockResultsManager < Literal::Object
  include Awfy::HasSession

  attr_reader :saved_results, :each_report_calls

  def after_initialize
    @saved_results = []
    @each_report_calls = []
  end

  def save_new_result(type, group, report, runtime, test, result_data, commit_hash: nil, commit_message: nil, branch: nil)
    result_id = "mock_result_#{@saved_results.size + 1}"
    @saved_results << {
      type: type,
      group: group,
      report: report,
      runtime: runtime,
      test: test,
      result_data: result_data,
      commit_hash: commit_hash,
      commit_message: commit_message,
      branch: branch,
      result_id: result_id
    }
    result_id
  end

  def each_report(type, &block)
    @each_report_calls << {type: type}
    # Yield mock results for testing
    if block_given? && !@saved_results.empty?
      by_report = @saved_results.group_by { |r| [r[:group].name, r[:report].name] }
      by_report.each do |(group_name, report_name), results|
        baseline = results.find { |r| r[:test].baseline? }
        yield results, baseline
      end
    end
  end

  def generate_test_label(test, runtime)
    "[#{runtime}] #{test.control? ? "[c]" : "[*]"}#{test.baseline? ? "[b]" : ""} #{test.name}"
  end
end
