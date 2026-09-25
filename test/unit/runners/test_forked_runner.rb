# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestForkedRunner < Minitest::Test
  include RunnerTestHelpers

  # A job that runs a block; a forked child sees the block's closure as it was at fork time.
  class BlockJob
    def initialize(&block)
      @block = block
    end

    def call = @block.call
  end

  def setup
    @test_dir = Dir.mktmpdir
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

  def two_group_suite
    groups = %w[first second].map do |name|
      test = Awfy::Suites::Test.new(name: "t", block: proc {})
      Awfy::Suites::Group.new(name: name, reports: [Awfy::Suites::Report.new(name: "r", tests: [test])])
    end
    Awfy::Suite.new(groups)
  end

  def marker(name) = File.join(@test_dir, name)

  # Waits in the child until the other group's marker exists, so the run only finishes when
  # the groups really run at the same time.
  def wait_for(path)
    deadline = Time.now + 10
    sleep 0.01 until File.exist?(path) || Time.now > deadline
    raise "timed out waiting for #{path}" unless File.exist?(path)
  end

  def test_inherits_from_base
    assert_kind_of Awfy::Runners::Base, @runner
  end

  def test_run_group_raises_without_block
    assert_raises(ArgumentError) { @runner.run_group(@suite.find_group("test_group")) }
  end

  def test_run_group_calls_the_job_in_a_child_process
    @runner.run_group(@suite.find_group("test_group")) do
      BlockJob.new { File.write(marker("pid"), Process.pid.to_s) }
    end

    child_pid = File.read(marker("pid")).to_i
    refute_equal 0, child_pid
    refute_equal Process.pid, child_pid
  end

  def test_the_job_cannot_change_the_parent_process
    state = {touched: false}

    @runner.run_group(@suite.find_group("test_group")) { BlockJob.new { state[:touched] = true } }

    refute state[:touched]
  end

  def test_run_group_raises_when_the_job_raises
    _, err = capture_io do
      error = assert_raises(RuntimeError) do
        @runner.run_group(@suite.find_group("test_group")) { BlockJob.new { raise "Test error in forked process" } }
      end
      assert_equal "Benchmark failed in forked process", error.message
    end

    assert_match(/Test error in forked process/, err)
  end

  def test_run_group_raises_when_the_job_raises_a_non_standard_error
    _, err = capture_io do
      assert_raises(RuntimeError) do
        @runner.run_group(@suite.find_group("test_group")) { BlockJob.new { raise NotImplementedError, "not here" } }
      end
    end

    assert_match(/not here/, err)
  end

  def test_run_group_raises_when_the_child_exits_without_reporting
    _, err = capture_io do
      assert_raises(RuntimeError) do
        @runner.run_group(@suite.find_group("test_group")) { BlockJob.new { exit!(3) } }
      end
    end

    assert_match(/exit status 3/, err)
  end

  def test_run_forks_every_group_at_the_same_time
    runner = Awfy::Runners::Parallel::ForkedRunner.new(suite: two_group_suite, session: @session)
    other = {"first" => "second", "second" => "first"}

    runner.run do |group|
      BlockJob.new do
        File.write(marker(group.name), Process.pid.to_s)
        wait_for(marker(other[group.name]))
      end
    end

    pids = %w[first second].map { |name| File.read(marker(name)).to_i }
    assert_equal 2, pids.uniq.size
    refute_includes pids, Process.pid
  end

  def test_run_reports_the_failing_group_and_still_runs_the_others
    runner = Awfy::Runners::Parallel::ForkedRunner.new(suite: two_group_suite, session: @session)

    _, err = capture_io do
      assert_raises(RuntimeError) do
        runner.run do |group|
          BlockJob.new do
            raise "first group failed" if group.name == "first"
            File.write(marker("second"), "ran")
          end
        end
      end
    end

    assert_match(/group 'first'.*first group failed/m, err)
    refute_match(/group 'second'/, err)
    assert File.exist?(marker("second"))
  end

  def test_run_with_a_group_name_runs_only_that_group
    runner = Awfy::Runners::Parallel::ForkedRunner.new(suite: two_group_suite, session: @session)

    runner.run("second") { |group| BlockJob.new { File.write(marker(group.name), "ran") } }

    assert File.exist?(marker("second"))
    refute File.exist?(marker("first"))
  end
end
