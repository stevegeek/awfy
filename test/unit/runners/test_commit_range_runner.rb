# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"
require "awfy/runners/base"
require "awfy/runners/commit_range_runner"
require "json"

class TestCommitRangeRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    @results_dir = File.join(@test_dir, "results")
    FileUtils.mkdir_p(@results_dir)

    # Use Thor::Shell::Basic as the shell
    @shell = Thor::Shell::Basic.new

    # Setup options
    @options = create_test_options(@test_dir)

    # Create a suite with mock groups
    @suite = create_mock_suite

    # Create mock Git client
    @git_client = create_mock_git_client

    # Create runner instance
    @runner = Awfy::Runners::CommitRangeRunner.new(@suite, @shell, @git_client, @options)

    # Add method stubs
    stub_runner_methods(@runner)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::CommitRangeRunner, @runner
    assert_nil @runner.start_time
  end

  def test_run_calls_commits_in_range
    # Mock the git commands for commit range
    commit_list = ["commit1", "commit2", "commit3"]

    # Stub the get_commits_in_range method
    @runner.define_singleton_method(:get_commits_in_range) do |start_commit, end_commit|
      # Record the start and end commits
      @range_args = [start_commit, end_commit]
      # Return a predefined list of commits
      commit_list
    end

    # Stub the run_on_commit method to return test results
    @runner.define_singleton_method(:run_on_commit) do |commit, group|
      # Record which commit is being run
      (@commits_run ||= []) << commit

      # Return test results for this commit
      {
        "test_group" => [
          {
            "name" => "test1",
            "runtime" => "ruby",
            "ips" => 100.0 + commit_list.index(commit) * 50,
            "commit" => commit,
            "commit_message" => "Test commit #{commit}"
          }
        ]
      }
    end

    # Run the benchmark over the commit range
    results = @runner.run("start_commit", "end_commit")

    # Check that run_on_commit was called for all commits in the range
    commits_run = @runner.instance_variable_get(:@commits_run)
    assert_equal commit_list, commits_run

    # Check that the range args were passed correctly
    range_args = @runner.instance_variable_get(:@range_args)
    assert_equal ["start_commit", "end_commit"], range_args

    # Check that the results were combined correctly
    assert_equal ["test_group"], results.keys
    assert_equal 3, results["test_group"].length

    # Verify each commit's results
    commit_list.each_with_index do |commit, idx|
      result = results["test_group"].find { |r| r["commit"] == commit }
      assert result, "Result for commit #{commit} not found"
      assert_equal 100.0 + idx * 50, result["ips"]
      assert_equal "Test commit #{commit}", result["commit_message"]
    end
  end

  def test_run_with_specific_group
    # Mock the git commands for commit range
    commit_list = ["commit1", "commit2"]

    # Stub the get_commits_in_range method
    @runner.define_singleton_method(:get_commits_in_range) do |start_commit, end_commit|
      commit_list
    end

    # Stub the run_on_commit method to check if the group is passed
    group_args = []
    @runner.define_singleton_method(:run_on_commit) do |commit, group|
      group_args << group

      # Return empty result
      {"test_group" => []}
    end

    # Run the benchmark with a specific group
    @runner.run("start", "end", "specific_group")

    # Check that the group was passed to run_on_commit for all commits
    assert_equal ["specific_group", "specific_group"], group_args
  end

  def test_get_commits_in_range
    # We need to override the git client commands for this test
    # Store the original lib method
    original_lib = @git_client.method(:lib)

    # Create a mock lib object
    mock_lib = Object.new
    mock_lib.define_singleton_method(:command) do |cmd, *args|
      case cmd
      when "rev-parse"
        if args.first == "start_commit"
          "abc123"
        elsif args.first == "end_commit"
          "def456"
        end
      when "rev-list"
        if args == ["--reverse", "abc123^..def456"]
          "abc123\nbcd234\ncde345\ndef456"
        end
      when "log"
        "Commit message for #{args.last}"
      else
        ""
      end
    end

    # Replace the git client's lib method
    @git_client.define_singleton_method(:lib) { mock_lib }

    begin
      # Call the method being tested
      commits = @runner.send(:get_commits_in_range, "start_commit", "end_commit")

      # Check the returned commits
      assert_equal ["abc123", "bcd234", "cde345", "def456"], commits
    ensure
      # Restore the original lib method
      @git_client.define_singleton_method(:lib, original_lib) if original_lib
    end
  end

  def test_combine_results_adds_new_results
    # Initial combined results
    all_results = {
      "group1" => [
        {"name" => "test1", "ips" => 100.0, "commit" => "commit1"}
      ]
    }

    # New results to add
    new_results = {
      "group1" => [
        {"name" => "test1", "ips" => 150.0, "commit" => "commit2"}
      ],
      "group2" => [
        {"name" => "test2", "ips" => 200.0, "commit" => "commit2"}
      ]
    }

    # Call the method being tested
    @runner.send(:combine_results!, all_results, new_results)

    # Check that the results were combined correctly
    assert_equal ["group1", "group2"].sort, all_results.keys.sort
    assert_equal 2, all_results["group1"].length
    assert_equal 1, all_results["group2"].length

    # Check that group1 has both commit results
    commit1_result = all_results["group1"].find { |r| r["commit"] == "commit1" }
    commit2_result = all_results["group1"].find { |r| r["commit"] == "commit2" }

    assert_equal 100.0, commit1_result["ips"]
    assert_equal 150.0, commit2_result["ips"]

    # Check that group2 has just the new result
    assert_equal "commit2", all_results["group2"][0]["commit"]
    assert_equal 200.0, all_results["group2"][0]["ips"]
  end
end
