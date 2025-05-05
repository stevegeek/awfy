# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"
require "awfy/runners/base"
require "awfy/runners/single_run_runner"
require "awfy/runners/branch_comparison_runner"
require "awfy/runners/commit_range_runner"
require "awfy/runners"

class TestRunnersFactory < Minitest::Test
  include RunnerTestHelpers

  def setup
    # Create basic objects needed for runner creation
    @shell = Thor::Shell::Basic.new
    @git_client = create_mock_git_client
    @suite = create_mock_suite
  end

  def test_create_single_run_runner
    # Basic options without branches or commit range
    options = OpenStruct.new(
      commit_range: nil,
      compare_with_branch: nil,
      command: "ips"
    )

    runner = Awfy::Runners.create(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::SingleRunRunner, runner
  end

  def test_create_branch_comparison_runner
    # Options with compare_with_branch
    options = OpenStruct.new(
      commit_range: nil,
      compare_with_branch: "feature",
      command: "ips"
    )

    runner = Awfy::Runners.create(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::BranchComparisonRunner, runner
  end

  def test_create_commit_range_runner
    # Options with commit_range
    options = OpenStruct.new(
      commit_range: "v1.0..v2.0",
      compare_with_branch: nil,
      command: "ips"
    )

    runner = Awfy::Runners.create(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::CommitRangeRunner, runner
  end

  def test_create_prioritizes_commit_range
    # Options with both commit_range and compare_with_branch
    # commit_range should take precedence
    options = OpenStruct.new(
      commit_range: "v1.0..v2.0",
      compare_with_branch: "feature",
      command: "ips"
    )

    runner = Awfy::Runners.create(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::CommitRangeRunner, runner
  end

  def test_factory_methods
    # Test the individual factory methods
    options = OpenStruct.new(command: "ips")

    single_runner = Awfy::Runners.single(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::SingleRunRunner, single_runner

    branch_runner = Awfy::Runners.on_branches(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::BranchComparisonRunner, branch_runner

    range_runner = Awfy::Runners.commit_range(@suite, @shell, @git_client, options)
    assert_instance_of Awfy::Runners::CommitRangeRunner, range_runner
  end
end
