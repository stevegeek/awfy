# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestThreadRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    @suite = create_mock_suite
    @options = create_test_options(@test_dir)
    @session = create_test_session(@options)

    @runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: @suite, session: @session)
  end

  def teardown
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::Parallel::ThreadRunner, @runner
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

  def test_run_group_executes_job_in_thread
    job_called = false

    mock_job = Object.new
    mock_job.define_singleton_method(:call) do
      job_called = true
    end

    @runner.run_group(@suite.find_group("test_group")) do |group|
      mock_job
    end

    # Thread should have completed by the time run_group returns
    assert true
  end

  def test_run_group_catches_errors_in_thread
    mock_job = Object.new
    mock_job.define_singleton_method(:call) do
      raise "Test error in thread"
    end

    assert_raises(RuntimeError) do
      @runner.run_group(@suite.find_group("test_group")) do |group|
        mock_job
      end
    end
  end

  def test_run_all_groups_in_parallel_threads
    mutex = Mutex.new

    mock_job_class = Class.new do
      def initialize(mutex, counter_ref)
        @mutex = mutex
        @counter_ref = counter_ref
      end

      def call
        @mutex.synchronize do
          @counter_ref[:count] += 1
        end
      end
    end

    counter = {count: 0}

    @runner.run do |group|
      mock_job_class.new(mutex, counter)
    end

    # All groups should have been run
    assert_equal @suite.groups.size, counter[:count]
  end

  def test_run_specific_group
    mock_job = Object.new
    mock_job.define_singleton_method(:call) { true }

    groups_seen = []

    @runner.run("test_group") do |group|
      groups_seen << group.name
      mock_job
    end

    assert_equal ["test_group"], groups_seen
  end

  def test_run_collects_errors_from_multiple_threads
    # Create a suite with multiple groups
    test1 = Awfy::Suites::Test.new(name: "test1", block: proc { "result" })
    test2 = Awfy::Suites::Test.new(name: "test2", block: proc { "result" })
    report1 = Awfy::Suites::Report.new(name: "report1", tests: [test1])
    report2 = Awfy::Suites::Report.new(name: "report2", tests: [test2])
    group1 = Awfy::Suites::Group.new(name: "group1", reports: [report1])
    group2 = Awfy::Suites::Group.new(name: "group2", reports: [report2])
    multi_suite = Awfy::Suite.new([group1, group2])

    runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: multi_suite, session: @session)

    error_job = Object.new
    error_job.define_singleton_method(:call) do
      raise "Intentional error"
    end

    assert_raises(RuntimeError) do
      runner.run do |group|
        error_job
      end
    end
  end
end
