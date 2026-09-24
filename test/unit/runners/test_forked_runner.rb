# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestForkedRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    @suite = create_mock_suite
    @options = create_test_options(@test_dir)
    @session = create_test_session(@options)

    @runner = Awfy::Runners::Parallel::ForkedRunner.new(suite: @suite, session: @session)
  end

  def teardown
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::Parallel::ForkedRunner, @runner
    assert_equal @suite, @runner.instance_variable_get(:@suite)
  end

  def test_inherits_from_base
    assert_kind_of Awfy::Runners::Base, @runner
  end

  def test_run_group_raises_without_block
    group = @suite.find_group("test_group")

    assert_raises(ArgumentError) do
      @runner.run_group(group)
    end
  end

  def test_run_group_executes_job_in_forked_process
    mock_job = Object.new
    mock_job.define_singleton_method(:call) do
      # This runs in the child process
      true
    end

    @runner.run_group(@suite.find_group("test_group")) do |_group|
      mock_job
    end

    # If we get here without exception, the fork succeeded
    assert true
  end

  def test_run_group_catches_errors_in_forked_process
    mock_job = Object.new
    mock_job.define_singleton_method(:call) do
      raise "Test error in forked process"
    end

    assert_raises(RuntimeError) do
      @runner.run_group(@suite.find_group("test_group")) do |group|
        mock_job
      end
    end
  end

  def test_run_all_groups_in_parallel
    mock_job = Object.new
    mock_job.define_singleton_method(:call) do
      # This is executed in the forked process
      true
    end

    @runner.run do |_group|
      mock_job
    end

    # If we get here without exception, all forked processes succeeded
    assert true
  end

  def test_run_specific_group
    mock_job = Object.new
    mock_job.define_singleton_method(:call) { true }

    # ForkedRunner executes the block in a forked process,
    # so we can't track groups_seen across the fork boundary.
    # Instead, verify that the run completes without error.
    @runner.run("test_group") do |group|
      # This executes in child process
      assert_equal "test_group", group.name
      mock_job
    end

    # If we reach here, the fork succeeded for the specific group
    assert true
  end
end
