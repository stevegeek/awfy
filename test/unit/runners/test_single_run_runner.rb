# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"
require "awfy/runners/base"
require "awfy/runners/single_run_runner"

class TestSingleRunRunner < Minitest::Test
  include RunnerTestHelpers

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

  def test_run_with_all_groups
    run_called = false

    # Create a simpler test that just verifies run_groups is called
    original_run_groups = @runner.method(:run_groups)

    @runner.define_singleton_method(:run_groups) do |&block|
      run_called = true
    end

    # Just test that run_groups is called, without checking what's yielded
    @runner.run { |group| }

    assert run_called, "run_groups should be called"
    assert_instance_of Integer, @runner.start_time

    # Restore original method
    @runner.define_singleton_method(:run_groups, original_run_groups)
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
