# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"
require "git_repo_helper"

# Runs BranchComparisonRunner against a real repository on `feature`, compared with `main`.
class TestBranchComparisonRunner < Minitest::Test
  include RunnerTestHelpers
  include GitRepoHelper

  attr_reader :repo

  def setup
    @repo = create_git_repo
    @main_sha = git(@repo, "rev-parse", "HEAD")
    git(@repo, "checkout", "-q", "-b", "feature")
    @feature_sha = commit_file(@repo, "file.txt", "feature\n", "Feature change")
    @suite = create_mock_suite
  end

  def teardown
    FileUtils.remove_entry(@repo) if @repo && Dir.exist?(@repo)
  end

  def session_for(compare_with_branch, **options)
    config = Awfy::Config.new(compare_with_branch:, storage_backend: Awfy::StoreAliases::Memory, **options)
    Awfy::Session.new(
      shell: Awfy::Shell.new(config:),
      config:,
      git_client: Awfy::GitClient.new(path: @repo),
      results_store: Awfy::Stores::Memory.new(storage_name: "test", retention_policy: Awfy::RetentionPolicies.keep_all)
    )
  end

  # The runner the commands get from Runners.create, with the child process replaced by a
  # recorder of the checked out ref, the working tree and the command line.
  def recording_runner(compare_with_branch, fail_on: nil)
    runner = Awfy::Runners.create(suite: @suite, session: session_for(compare_with_branch))
    runs = []
    test = self
    runner.define_singleton_method(:run_in_child_process) do |command|
      runs << {ref: test.head_ref(test.repo), file: test.read_file(test.repo, "file.txt"), argv: command.argv}
      raise "child failed" if runs.last[:ref] == fail_on
    end
    [runner, runs]
  end

  def run_group_job(session)
    Awfy::Jobs::RunGroup.new(session:, group: @suite.find_group("test_group"),
      benchmarker: Awfy::Benchmarker.new(session:), results_manager: Awfy::ResultsManager.new(session:))
  end

  def test_the_factory_picks_it_for_compare_with_branch
    assert_instance_of Awfy::Runners::Sequential::BranchComparisonRunner,
      Awfy::Runners.create(suite: @suite, session: session_for("main"))
  end

  def test_runs_the_working_tree_then_the_comparison_branch_as_control
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    runner, runs = recording_runner("main")

    runner.run { |group| run_group_job(session_for("main")) }

    assert_equal ["feature", "main"], runs.map { |run| run[:ref] }
    assert_equal ["work in progress\n", "main\n"], runs.map { |run| run[:file] }
    assert_includes runs.first[:argv], "--no-summary"
    refute(runs.first[:argv].any? { |arg| arg.start_with?("--control-commit") })
    assert_includes runs.last[:argv], "--control-commit=#{@main_sha}"
    assert_includes runs.last[:argv], "--summary"
    assert_equal %w[suite debug test_group], runs.first[:argv][3, 3]
  end

  def test_returns_to_the_branch_with_uncommitted_changes
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    runner, _runs = recording_runner("main")

    runner.run("test_group") { |group| run_group_job(session_for("main")) }

    assert_equal "feature", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_restores_the_working_tree_when_the_comparison_run_fails
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    runner, runs = recording_runner("main", fail_on: "main")

    assert_raises(RuntimeError) { runner.run("test_group") { |group| run_group_job(session_for("main")) } }

    assert_equal 2, runs.size
    assert_equal "feature", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_an_unknown_branch_fails_before_anything_runs
    runner, runs = recording_runner("no-such-branch")

    error = assert_raises(Awfy::Errors::GitStateError) do
      runner.run("test_group") { |group| run_group_job(session_for("no-such-branch")) }
    end

    assert_match(/no-such-branch/, error.message)
    assert_empty runs
  end

  def test_refuses_to_start_while_a_merge_is_in_progress
    git(@repo, "checkout", "-q", "-b", "side", @main_sha)
    commit_file(@repo, "file.txt", "side\n", "Side change")
    git(@repo, "checkout", "-q", "feature")
    Open3.capture3("git", "-C", @repo, "merge", "side")
    runner, runs = recording_runner("main")

    assert_raises(Awfy::Errors::UnsafeCheckoutError) do
      runner.run("test_group") { |group| run_group_job(session_for("main")) }
    end

    assert_empty runs
  end

  # End to end: real child awfy processes load the suite from each checkout in turn.
  def test_child_processes_run_the_code_of_each_branch
    log_dir = File.realpath(Dir.mktmpdir("awfy_branch_log"))
    log = File.join(log_dir, "runs.log")
    suite_code = <<~RUBY
      Awfy.group "Probe" do
        report "value" do
          test "records the checked out code" do
            File.write(#{log.inspect}, File.read(File.join(__dir__, "..", "..", "file.txt")), mode: "a")
          end
        end
      end
    RUBY
    git(@repo, "checkout", "-q", "main")
    commit_file(@repo, "benchmarks/setup.rb", "", "Add setup")
    commit_file(@repo, "benchmarks/tests/probe.rb", suite_code, "Add probe")
    git(@repo, "checkout", "-q", "feature")
    git(@repo, "merge", "-q", "--no-edit", "main")
    File.write(File.join(@repo, "file.txt"), "work in progress\n")

    session = session_for("main", runtime: "mri", test_iterations: 1, color: Awfy::ColorMode::OFF,
      setup_file_path: "./benchmarks/setup", tests_path: "./benchmarks/tests")
    probe = Awfy::Suites::Group.new(name: "Probe", reports: [
      Awfy::Suites::Report.new(name: "value", tests: [Awfy::Suites::Test.new(name: "records the checked out code", block: proc {})])
    ])
    runner = Awfy::Runners.create(suite: Awfy::Suite.new([probe]), session:)

    Dir.chdir(@repo) do
      capture_io { runner.run("Probe") { |group| Awfy::Jobs::RunGroup.new(session:, group:, benchmarker: Awfy::Benchmarker.new(session:), results_manager: Awfy::ResultsManager.new(session:)) } }
    end

    # A test may run more than once per child; what matters is which code each child saw, in order.
    assert_equal ["work in progress\n", "main\n"], File.read(log).lines.chunk_while { |a, b| a == b }.map(&:first)
    assert_equal "feature", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
  ensure
    FileUtils.remove_entry(log_dir) if log_dir
  end
end
