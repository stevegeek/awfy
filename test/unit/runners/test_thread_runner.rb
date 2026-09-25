# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestThreadRunner < Minitest::Test
  include RunnerTestHelpers

  class BlockJob
    def initialize(&block)
      @block = block
    end

    def call = @block.call
  end

  def setup
    @suite = create_mock_suite
    @options = create_test_options(nil)
    @session = create_test_session(@options)

    @runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: @suite, session: @session)
  end

  def two_group_suite
    groups = %w[first second].map do |name|
      test = Awfy::Suites::Test.new(name: "t", block: proc {})
      Awfy::Suites::Group.new(name: name, reports: [Awfy::Suites::Report.new(name: "r", tests: [test])])
    end
    Awfy::Suite.new(groups)
  end

  def test_inherits_from_base
    assert_kind_of Awfy::Runners::Base, @runner
  end

  def test_run_group_raises_without_block
    assert_raises(ArgumentError) { @runner.run_group(@suite.find_group("test_group")) }
  end

  def test_run_group_calls_the_job_in_another_thread_of_this_process
    seen = {}

    @runner.run_group(@suite.find_group("test_group")) do
      BlockJob.new { seen.update(thread: Thread.current, pid: Process.pid) }
    end

    refute_nil seen[:thread], "the job has finished when run_group returns"
    refute_same Thread.current, seen[:thread]
    assert_equal Process.pid, seen[:pid]
  end

  def test_run_group_raises_and_reports_the_error_from_the_thread
    _, err = capture_io do
      error = assert_raises(RuntimeError) do
        @runner.run_group(@suite.find_group("test_group")) { BlockJob.new { raise "Test error in thread" } }
      end
      assert_equal "Benchmark failed in Thread", error.message
    end

    assert_match(/Test error in thread/, err)
  end

  def test_run_starts_every_group_before_waiting_for_any
    runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: two_group_suite, session: @session)
    started = Queue.new
    release = Queue.new
    finished = []

    waiter = Thread.new do
      # Both jobs must be running at once before either is let go.
      2.times { started.pop(timeout: 10) || raise("jobs did not run at the same time") }
      2.times { release << true }
    end

    runner.run do |group|
      BlockJob.new do
        started << group.name
        release.pop(timeout: 10) || raise("never released")
        finished << group.name
      end
    end
    waiter.join

    assert_equal %w[first second], finished.sort
  end

  def test_run_reports_every_failing_group
    runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: two_group_suite, session: @session)

    _, err = capture_io do
      error = assert_raises(RuntimeError) do
        runner.run { |group| BlockJob.new { raise "#{group.name} broke" } }
      end
      assert_equal "Benchmark failed in one or more Threads", error.message
    end

    assert_match(/group 'first'.*first broke/m, err)
    assert_match(/group 'second'.*second broke/m, err)
  end

  def test_run_with_a_group_name_runs_only_that_group
    runner = Awfy::Runners::Parallel::ThreadRunner.new(suite: two_group_suite, session: @session)
    ran = []

    runner.run("second") { |group| BlockJob.new { ran << group.name } }

    assert_equal ["second"], ran
  end
end
