# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"
require "git_repo_helper"

# Runs CommitRangeRunner against a real repository. Only the child awfy process is replaced:
# it records which commit was checked out, and what the working tree held, when it ran.
class TestCommitRangeRunner < Minitest::Test
  include RunnerTestHelpers
  include GitRepoHelper

  def setup
    @repo = create_git_repo
    @first = git(@repo, "rev-parse", "HEAD")
    @second = commit_file(@repo, "file.txt", "second\n", "Second commit")
    @third = commit_file(@repo, "file.txt", "third\n", "Third commit")
    @suite = create_mock_suite
    @group = @suite.find_group("test_group")
  end

  attr_reader :repo

  def teardown
    FileUtils.remove_entry(@repo) if @repo && Dir.exist?(@repo)
  end

  def runner_for(commit_range, control_commit: nil, fail_on: nil)
    config = Awfy::Config.new(commit_range:, control_commit:, storage_backend: Awfy::StoreAliases::Memory)
    session = Awfy::Session.new(
      shell: Awfy::Shell.new(config:),
      config:,
      git_client: Awfy::GitClient.new(path: @repo),
      results_store: Awfy::Stores::Memory.new(storage_name: "test", retention_policy: Awfy::RetentionPolicies.keep_all)
    )
    runs = []
    runner = Awfy::Runners::Sequential::CommitRangeRunner.new(suite: @suite, session:)
    test = self
    runner.define_singleton_method(:run_in_child_process) do |command|
      runs << {head: test.git(test.repo, "rev-parse", "HEAD"), file: test.read_file(test.repo, "file.txt"), argv: command.argv}
      raise "child failed" if runs.last[:head] == fail_on
    end
    [runner, runs]
  end

  def ips_job
    config = Awfy::Config.new(storage_backend: Awfy::StoreAliases::Memory)
    session = create_test_session(config)
    Awfy::Jobs::IPS.new(session:, group: @group, benchmarker: Awfy::Benchmarker.new(session:),
      results_manager: Awfy::ResultsManager.new(session:))
  end

  def test_runs_every_commit_in_the_range_oldest_first
    runner, runs = runner_for("#{@first}..#{@third}")

    runner.run("test_group") { ips_job }

    assert_equal [@first, @second, @third], runs.map { |run| run[:head] }
    assert_equal ["main\n", "second\n", "third\n"], runs.map { |run| run[:file] }
    assert(runs.all? { |run| run[:argv].include?("--control-commit=#{@first}") })
    assert_equal %w[ips start test_group], runs.first[:argv][3, 3]
  end

  def test_an_explicit_control_commit_is_resolved_to_its_full_sha
    runner, runs = runner_for("#{@second}..#{@third}", control_commit: @third[0, 7])

    runner.run("test_group") { ips_job }

    assert_equal [@second, @third], runs.map { |run| run[:head] }
    assert_includes runs.first[:argv], "--control-commit=#{@third}"
  end

  def test_a_single_commit_runs_once
    runner, runs = runner_for(@second)

    runner.run("test_group") { ips_job }

    assert_equal [@second], runs.map { |run| run[:head] }
  end

  def test_returns_to_the_branch_and_restores_uncommitted_changes
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    runner, runs = runner_for("#{@first}..#{@second}")

    runner.run("test_group") { ips_job }

    assert_equal ["main\n", "second\n"], runs.map { |run| run[:file] }
    assert_equal "main", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_restores_the_working_tree_when_a_commit_fails
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    runner, runs = runner_for("#{@first}..#{@third}", fail_on: @second)

    assert_raises(RuntimeError) { runner.run("test_group") { ips_job } }

    assert_equal [@first, @second], runs.map { |run| run[:head] }
    assert_equal "main", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_returns_to_a_detached_head
    git(@repo, "checkout", "-q", "--detach", @second)
    runner, _runs = runner_for("#{@first}..#{@third}")

    runner.run("test_group") { ips_job }

    assert_equal @second, head_ref(@repo)
  end

  def test_refuses_to_start_while_a_merge_is_in_progress
    git(@repo, "checkout", "-q", "-b", "side", @second)
    commit_file(@repo, "file.txt", "side\n", "Side change")
    git(@repo, "checkout", "-q", "main")
    Open3.capture3("git", "-C", @repo, "merge", "side")
    runner, runs = runner_for("#{@first}..#{@third}")

    assert_raises(Awfy::Errors::UnsafeCheckoutError) { runner.run("test_group") { ips_job } }

    assert_empty runs
  end

  def test_rejects_an_invalid_range
    runner, runs = runner_for("a..b..c")

    assert_raises(ArgumentError) { runner.run("test_group") { ips_job } }
    assert_empty runs
  end
end
