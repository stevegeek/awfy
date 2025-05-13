# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestRunnersFactory < Minitest::Test
  include RunnerTestHelpers

  def setup
    # Create basic objects needed for runner creation
    @suite = create_mock_suite
    @options = create_test_options(nil) # Creates options with default runner: "immediate"
    @session = create_test_session(@options)
  end

  def test_create_single_run_runner
    # Basic options without branches or commit range
    # Default runner type is "immediate" from create_test_options
    runner = Awfy::Runners.create(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Sequential::ImmediateRunner, runner
  end

  def test_create_branch_comparison_runner
    # Options with compare_with_branch
    options = Awfy::Config.new(
      commit_range: nil,
      compare_with_branch: "feature",
      runner: Awfy::RunnerTypes::IMMEDIATE
    )
    session = create_test_session(options)

    runner = Awfy::Runners.create(suite: @suite, session: session)
    assert_instance_of Awfy::Runners::Sequential::BranchComparisonRunner, runner
  end

  def test_create_commit_range_runner
    # Options with commit_range
    options = Awfy::Config.new(
      commit_range: "v1.0..v2.0",
      compare_with_branch: nil,
      runner: Awfy::RunnerTypes::IMMEDIATE
    )
    session = create_test_session(options)

    runner = Awfy::Runners.create(suite: @suite, session: session)
    assert_instance_of Awfy::Runners::Sequential::CommitRangeRunner, runner
  end

  def test_create_prioritizes_commit_range
    # Options with both commit_range and compare_with_branch
    # commit_range should take precedence
    options = Awfy::Config.new(
      commit_range: "v1.0..v2.0",
      compare_with_branch: "feature",
      runner: Awfy::RunnerTypes::IMMEDIATE
    )
    session = create_test_session(options)

    runner = Awfy::Runners.create(suite: @suite, session: session)
    assert_instance_of Awfy::Runners::Sequential::CommitRangeRunner, runner
  end

  def test_factory_methods
    # Test the individual factory methods
    immediate_runner = Awfy::Runners.immediate(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Sequential::ImmediateRunner, immediate_runner

    spawn_runner = Awfy::Runners.spawn(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Sequential::SpawnRunner, spawn_runner

    thread_runner = Awfy::Runners.thread(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Parallel::ThreadRunner, thread_runner

    forked_runner = Awfy::Runners.forked(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Parallel::ForkedRunner, forked_runner

    branch_runner = Awfy::Runners.on_branches(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Sequential::BranchComparisonRunner, branch_runner

    range_runner = Awfy::Runners.commit_range(suite: @suite, session: @session)
    assert_instance_of Awfy::Runners::Sequential::CommitRangeRunner, range_runner
  end
end
