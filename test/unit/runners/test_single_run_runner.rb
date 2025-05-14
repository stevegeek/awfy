# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestSingleRunRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    # Create basic objects needed for runner creation
    @suite = create_mock_suite
    @options = create_test_options(@test_dir)
    @session = create_test_session(@options)

    # Create runner instance
    @runner = Awfy::Runners::Sequential::ImmediateRunner.new(suite: @suite, session: @session)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::Sequential::ImmediateRunner, @runner
    # Access suite through instance variable since there may not be a reader method
    assert_equal @suite, @runner.instance_variable_get(:@suite)
    # start_time is now set in start! method, so we can't test it directly here
  end

  def test_run_group_executes_block
    # Track which groups were run
    run_groups = []

    # Create a mock job object that responds to 'call'
    mock_job = Object.new
    def mock_job.call
      # Simulates a job that executes
      true
    end

    # Run a specific group
    @runner.run("test_group") do |group|
      run_groups << group.name
      # Return a callable job as expected by the runner
      mock_job
    end

    # Verify only the specified group was run
    assert_equal ["test_group"], run_groups
  end

  def test_run_all_groups_executes_block_for_each
    # Track which groups were run
    run_groups = []

    # Create a mock job object that responds to 'call'
    mock_job = Object.new
    def mock_job.call
      # Simulates a job that executes
      true
    end

    # Run all groups (no specific group name)
    @runner.run do |group|
      run_groups << group.name
      # Return a callable job as expected by the runner
      mock_job
    end

    # Verify all groups were run
    assert_equal @suite.groups.map(&:name), run_groups
  end
end
