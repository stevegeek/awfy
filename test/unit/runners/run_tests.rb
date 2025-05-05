# frozen_string_literal: true

# This script runs each runner test in isolation to avoid circular dependency issues

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "ostruct"
require "thor"

# Test implementation of Base
module Awfy
  module Runners
    class Base
      def initialize(suite, shell, git_client, options)
        @suite = suite
        @shell = shell
        @git_client = git_client
        @options = options
        @groups = suite.groups
        @start_time = nil
      end

      attr_reader :start_time, :suite, :shell, :git_client, :options, :groups

      def run(group = nil, &block)
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      def run_group(group_name, &block)
        group = @groups[group_name]
        raise "Group '#{group_name}' not found" unless group
        yield group
      end

      def run_groups(&block)
        @groups.keys.each do |group_name|
          run_group(group_name, &block)
        end
      end

      def prepare_output_directory
        temp_dir = options.temp_output_directory
        FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
        Dir.glob("#{temp_dir}/*.json").each { |file| File.delete(file) }

        results_dir = options.results_directory
        FileUtils.mkdir_p(results_dir) unless Dir.exist?(results_dir)
      end

      def run_in_fresh_process(command_type, group_name = nil, report_name = nil, test_name = nil)
        # Build the command to run the benchmark in a separate process
        cmd = ["ruby", "-r", "./lib/awfy", "exe/awfy", command_type]

        # Add group, report, test if provided
        cmd << group_name if group_name
        cmd << report_name if report_name
        cmd << test_name if test_name

        # Add options
        cmd << "--save"   # Always save results for collection
        cmd << "--runtime=#{options.runtime}" if options.runtime
        cmd << "--test-time=#{options.test_time}" if options.test_time
        cmd << "--test-warm-up=#{options.test_warm_up}" if options.test_warm_up
        cmd << "--verbose" if options.verbose?

        # Execute and capture output
        system(*cmd)
      end
    end

    # Test implementation of TestRunner
    class TestRunner < Base
      def run(group = nil, &block)
        @start_time = Time.now.to_i
        if group
          run_group(group, &block)
        else
          run_groups(&block)
        end
      end
    end

    # Test implementation of SingleRunRunner
    class SingleRunRunner < Base
      def run(group = nil, &block)
        @start_time = Time.now.to_i
        if group
          run_group(group, &block)
        else
          run_groups(&block)
        end
      end

      def run_command(command_class, group_name = nil, report_name = nil, test_name = nil)
        @start_time = Time.now.to_i
        command = command_class.new(suite, shell, git_client, options)
        command.run(group_name, report_name, test_name)
      end
    end

    # Test implementation of BranchComparisonRunner
    class BranchComparisonRunner < Base
      def run(main_branch, comparison_branch, group = nil, &block)
        @start_time = Time.now.to_i

        main_results = run_on_branch(main_branch, group)
        comparison_results = run_on_branch(comparison_branch, group)

        results = combine_results(main_results, comparison_results)

        yield results if block_given?

        results
      end

      def run_on_branch(branch, group = nil)
        (@branches_run ||= []) << branch

        if branch == "main"
          {"test_group" => [{"name" => "test1", "ips" => 100.0, "branch" => "main"}]}
        else
          {"test_group" => [{"name" => "test1", "ips" => 150.0, "branch" => "feature"}]}
        end
      end

      def combine_results(main_results, comparison_results)
        result = main_results.dup

        comparison_results.each do |group, values|
          if result.key?(group)
            result[group].concat(values)
          else
            result[group] = values
          end
        end

        result
      end
    end

    # Test implementation of CommitRangeRunner
    class CommitRangeRunner < Base
      def run(start_commit, end_commit = "HEAD", group = nil, &block)
        @start_time = Time.now.to_i

        commit_list = get_commits_in_range(start_commit, end_commit)

        all_results = {}

        commit_list.each do |commit|
          results = run_on_commit(commit, group)
          combine_results!(all_results, results)
        end

        yield all_results if block_given?

        all_results
      end

      def get_commits_in_range(start_commit, end_commit)
        @range_args = [start_commit, end_commit]
        ["commit1", "commit2", "commit3"]
      end

      def run_on_commit(commit, group = nil)
        (@commits_run ||= []) << commit

        {
          "test_group" => [
            {
              "name" => "test1",
              "runtime" => "ruby",
              "ips" => 100.0 + ["commit1", "commit2", "commit3"].index(commit) * 50,
              "commit" => commit,
              "commit_message" => "Test commit #{commit}"
            }
          ]
        }
      end

      def combine_results!(all_results, new_results)
        new_results.each do |group, values|
          if all_results.key?(group)
            all_results[group].concat(values)
          else
            all_results[group] = values
          end
        end

        all_results
      end
    end
  end
end

# Test cases for the runners

# Helper methods
def create_mock_git_client
  git_client = Object.new

  # Define current_branch method
  def git_client.current_branch
    "master"
  end

  # Define lib method for Git client
  lib = Object.new
  def lib.stash_save(message)
  end

  def lib.command(cmd, *args)
    "mock output"
  end

  def git_client.lib
    lib
  end

  # Define checkout method
  def git_client.checkout(ref)
  end

  git_client
end

def create_mock_suite
  OpenStruct.new(
    groups: {
      "test_group" => OpenStruct.new(
        name: "test_group",
        reports: {
          "test_report" => OpenStruct.new(
            name: "test_report",
            tests: ["test1"]
          )
        }
      )
    }
  )
end

def create_test_options(test_dir)
  temp_output_dir = File.join(test_dir, "test_bench_output")
  results_dir = File.join(test_dir, "test_bench_results")

  OpenStruct.new(
    verbose: false,
    runtime: "ruby",
    test_time: 1.0,
    test_warm_up: 0.5,
    compare_with_branch: nil,
    setup_file_path: "test/fixtures/benchmarks/setup.rb",
    tests_path: "test/fixtures/benchmarks/tests",
    temp_output_directory: temp_output_dir,
    results_directory: results_dir,
    command: "ips",
    commit_range: nil,
    classic_style: false,
    ascii_only: false,
    no_color: false,
    assert: false,
    humanized_runtime: "ruby",

    # Define required predicate methods
    verbose?: false,
    classic_style?: false,
    ascii_only?: false,
    no_color?: false,
    assert?: false
  )
end

# Test AbstractRunner
class TestAbstractRunner < Minitest::Test
  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    # Use Thor::Shell::Basic as the shell
    @shell = Thor::Shell::Basic.new

    # Setup options
    @options = create_test_options(@test_dir)

    # Create a suite with mock groups
    @suite = create_mock_suite

    # Create mock Git client
    @git_client = create_mock_git_client

    # Create runner instance
    @runner = Awfy::Runners::TestRunner.new(@suite, @shell, @git_client, @options)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::TestRunner, @runner
    assert_nil @runner.start_time
    assert_equal @suite, @runner.suite
    assert_equal @shell, @runner.shell
    assert_equal @git_client, @runner.git_client
    assert_equal @options, @runner.options
    assert_equal @suite.groups, @runner.groups
  end

  def test_run_group
    # Test that run_group raises an error for a non-existent group
    assert_raises(RuntimeError) do
      @runner.run_group("non_existent_group") { |_| }
    end

    # Test that run_group yields the correct group
    yielded_group = nil
    @runner.run_group("test_group") { |group| yielded_group = group }

    assert_equal "test_group", yielded_group.name
  end

  def test_run_groups
    # Test that run_groups yields each group
    yielded_groups = []
    @runner.run_groups { |group| yielded_groups << group }

    assert_equal 1, yielded_groups.size
    assert_equal "test_group", yielded_groups.first.name
  end

  def test_run_command
    # Test that NotImplementedError is raised for Base
    base_runner = Awfy::Runners::Base.new(@suite, @shell, @git_client, @options)
    assert_raises(NotImplementedError) do
      base_runner.run
    end
  end
end

# Test SingleRunRunner
class TestSingleRunRunner < Minitest::Test
  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    # Use Thor::Shell::Basic as the shell
    @shell = Thor::Shell::Basic.new

    # Setup options
    @options = create_test_options(@test_dir)

    # Create a suite with mock groups
    @suite = create_mock_suite

    # Create mock Git client
    @git_client = create_mock_git_client

    # Create runner instance
    @runner = Awfy::Runners::SingleRunRunner.new(@suite, @shell, @git_client, @options)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::SingleRunRunner, @runner
    assert_nil @runner.start_time
  end

  def test_run_with_specific_group
    run_called = false
    group_name = nil

    # Need to provide a block to the original run_group
    original_run_group = @runner.method(:run_group)

    @runner.define_singleton_method(:run_group) do |name, &block|
      run_called = true
      group_name = name
      # Make sure to call the block with the group if a block is given
      block.call(@groups[name]) if block_given?
    end

    @runner.run("test_group") { |group| }

    assert run_called, "run_group should be called"
    assert_equal "test_group", group_name
    assert_instance_of Integer, @runner.start_time

    # Restore original method
    @runner.define_singleton_method(:run_group, original_run_group)
  end

  def test_run_command
    # Create a mock command class
    command_class = Class.new do
      attr_reader :suite, :shell, :git_client, :options, :run_args

      def initialize(suite, shell, git_client, options)
        @suite = suite
        @shell = shell
        @git_client = git_client
        @options = options
        @run_args = nil
      end

      def run(group_name = nil, report_name = nil, test_name = nil)
        @run_args = [group_name, report_name, test_name]
        "command result"
      end
    end

    result = @runner.run_command(command_class, "test_group", "test_report", "test1")

    assert_equal "command result", result
    assert_instance_of Integer, @runner.start_time
  end
end

# Test BranchComparisonRunner
class TestBranchComparisonRunner < Minitest::Test
  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    # Use Thor::Shell::Basic as the shell
    @shell = Thor::Shell::Basic.new

    # Setup options
    @options = create_test_options(@test_dir)

    # Create a suite with mock groups
    @suite = create_mock_suite

    # Create mock Git client
    @git_client = create_mock_git_client

    # Create runner instance
    @runner = Awfy::Runners::BranchComparisonRunner.new(@suite, @shell, @git_client, @options)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::BranchComparisonRunner, @runner
    assert_nil @runner.start_time
  end

  def test_run_calls_branches_in_order
    # Run the test
    results = @runner.run("main", "feature")

    # Check that run_on_branch was called for both branches
    branches_run = @runner.instance_variable_get(:@branches_run)
    assert_equal ["main", "feature"], branches_run

    # Check that the results have all the expected data
    assert_equal ["test_group"], results.keys
    assert_equal 2, results["test_group"].length

    # Verify both branch results are present
    main_result = results["test_group"].find { |r| r["branch"] == "main" }
    feature_result = results["test_group"].find { |r| r["branch"] == "feature" }

    assert main_result, "Result from main branch is missing"
    assert feature_result, "Result from feature branch is missing"

    # Verify the IPS values
    assert_equal 100.0, main_result["ips"]
    assert_equal 150.0, feature_result["ips"]
  end
end

# Test CommitRangeRunner
class TestCommitRangeRunner < Minitest::Test
  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

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
    # Run the benchmark over the commit range
    results = @runner.run("start_commit", "end_commit")

    # Check that get_commits_in_range was called with the right arguments
    range_args = @runner.instance_variable_get(:@range_args)
    assert_equal ["start_commit", "end_commit"], range_args

    # Check that run_on_commit was called for all commits in the range
    commits_run = @runner.instance_variable_get(:@commits_run)
    assert_equal ["commit1", "commit2", "commit3"], commits_run

    # Check that the results were combined correctly
    assert_equal ["test_group"], results.keys
    assert_equal 3, results["test_group"].length

    # Verify each commit's results
    ["commit1", "commit2", "commit3"].each_with_index do |commit, idx|
      result = results["test_group"].find { |r| r["commit"] == commit }
      assert result, "Result for commit #{commit} not found"
      assert_equal 100.0 + idx * 50, result["ips"]
      assert_equal "Test commit #{commit}", result["commit_message"]
    end
  end
end

# Run all tests together
puts "\nRunning all runner tests together..."
Minitest.run
