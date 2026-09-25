# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PassRunnerTest < Minitest::Test
  LOG = []

  class Light < Awfy::Collector
    def self.key = "light"

    def start(context) = LOG << [:light_start, context.pass]

    def stop(context)
      LOG << [:light_stop, context.pass]
      {"n" => 1}
    end
  end

  class Late < Awfy::Collector
    def self.key = "late"

    def self.order = 100

    def stop(_context)
      LOG << :late_stop
      {}
    end
  end

  class Heavy < Awfy::Collector
    def self.key = "heavy"

    def self.heavy? = true

    def around(context)
      LOG << [:heavy_around, context.pass]
      yield
    end

    def stop(_context) = {"h" => 2}
  end

  module Probe
    def self.available? = true

    def self.wrap
      LOG << :wrap
      yield
    end
  end

  class LowOrder < Awfy::Collector
    def self.key = "low_order"

    def self.order = -10

    def stop(_context)
      LOG << [:stop, :low]
      {}
    end
  end

  class HighOrder < Awfy::Collector
    def self.key = "high_order"

    def self.order = 10

    def stop(_context)
      LOG << [:stop, :high]
      {}
    end
  end

  class RaisingStop < Awfy::Collector
    def self.key = "raising_stop"

    def self.order = -20

    def stop(_context)
      LOG << [:stop, :raising]
      raise "stop boom"
    end
  end

  def setup
    LOG.clear
    Awfy::Isolation.register(:probe, Probe)
  end

  def runner(*collectors) = Awfy::PassRunner.new(collectors:, label: "l", artefacts_dir: Dir.tmpdir)

  def first_test(suite)
    group = suite.groups.first
    report = group.reports.first
    [group, report, report.tests.first]
  end

  def build(&block)
    suite = Awfy::Suite.new
    suite.group("G", &block)
    group, report, test = first_test(suite)
    group.hooks.isolate ||= :probe
    [group, report, test]
  end

  def test_warm_up_then_light_pass_then_one_pass_per_heavy
    calls = 0
    group, report, test = build { report("R") { test("t") { calls += 1 } } }
    measurement = runner(Light, Heavy).measure(group, report, test)
    assert_equal 3, calls
    assert_equal [[:light_start, 1], [:light_stop, 1], [:heavy_around, 2]], LOG.reject { it == :wrap }
    assert_equal({"light" => {"n" => 1}, "heavy" => {"h" => 2}}, measurement.collectors)
    assert_equal "probe", measurement.isolation
  end

  def test_hooks_and_isolation_wrap_every_call_including_warm_up
    events = []
    group, report, test = build do
      before_each { events << :before }
      after_each { events << :after }
      report("R") { test("t") { events << :call } }
    end
    runner(Light).measure(group, report, test)
    assert_equal [:before, :call, :after] * 2, events
    assert_equal 2, LOG.count(:wrap)
  end

  def test_report_hooks_override_group_hooks_and_setup_runs_once
    events = []
    group, report, test = build do
      setup { events << :group_setup }
      before_each { events << :group_before }
      report("R") do
        before_each { events << :report_before }
        test("t") {}
        test("u") {}
      end
    end
    pass_runner = runner(Light)
    pass_runner.measure(group, report, test)
    pass_runner.measure(group, report, report.tests.last)
    assert_equal 1, events.count(:group_setup)
    assert_equal 0, events.count(:group_before)
    assert_equal 4, events.count(:report_before)
  end

  def test_rss_like_collectors_stop_last
    group, report, test = build { report("R") { test("t") {} } }
    runner(Late, Light).measure(group, report, test)
    assert_equal :late_stop, LOG.reject { it == :wrap }.last
  end

  def test_outcome_comes_from_the_light_pass
    group, report, test = build { report("R") { test("t") { Awfy::Outcome.record { |c| c.keys } } } }
    assert_equal ["light"], runner(Light, Heavy).measure(group, report, test).outcome
  end

  def test_error_still_runs_after_each_and_stops_collectors
    events = []
    group, report, test = build do
      after_each { events << :after }
      report("R") { test("t") { raise "boom" } }
    end
    assert_raises(RuntimeError) { runner(Light).measure(group, report, test) }
    assert_equal [:after], events, "the warm-up raised, after_each still ran"
    group.hooks.before_each = -> { events << :before }
    calls = 0
    test2 = Awfy::Suites::BaselineTest.new(name: "t2", block: -> { ((calls += 1) > 1) ? raise("boom") : nil })
    assert_raises(RuntimeError) { runner(Light).measure(group, report, test2) }
    assert_equal [[:light_start, 1], [:light_stop, 1]], LOG.reject { it == :wrap }, "started collectors are stopped"
  end

  def test_a_failing_setup_fails_every_test_of_the_group_with_that_error
    calls = 0
    group, report, test = build do
      setup {
        calls += 1
        raise "setup boom"
      }
      report("R") do
        test("t") {}
        test("u") {}
      end
    end
    pass_runner = runner(Light)
    error = assert_raises(RuntimeError) { pass_runner.measure(group, report, test) }
    assert_equal "setup boom", error.message
    error = assert_raises(RuntimeError) { pass_runner.measure(group, report, report.tests.last) }
    assert_equal "setup boom", error.message
    assert_equal 2, calls, "a hook is only marked done once its setup succeeds, so it is retried, not skipped"
  end

  def test_error_stops_started_collectors_lowest_order_first
    group, report, _test = build { report("R") { test("t") {} } }
    calls = 0
    test = Awfy::Suites::BaselineTest.new(name: "t", block: -> { ((calls += 1) > 1) ? raise("boom") : nil })
    assert_raises(RuntimeError) { runner(LowOrder, HighOrder).measure(group, report, test) }
    assert_equal [[:stop, :low], [:stop, :high]], LOG.reject { it == :wrap },
      "stop in ascending .order, the reverse of the descending start order"
  end

  def test_memory_profiler_stop_after_a_test_error_does_not_warn
    calls = 0
    group, report, test = build { report("R") { test("t") { ((calls += 1) >= 3) ? raise("boom") : nil } } }
    pass_runner = runner(Awfy::Collectors::MemoryProfiler)
    _, err = capture_io { assert_raises(RuntimeError) { pass_runner.measure(group, report, test) } }
    assert_empty err, "#stop returns {} when @report is nil instead of raising and " \
      "triggering stop_after_error's 'could not stop' warning"
  end

  def test_a_raising_stop_does_not_prevent_a_later_collectors_stop
    group, report, test = build { report("R") { test("t") {} } }
    error = assert_raises(RuntimeError) { runner(RaisingStop, LowOrder, HighOrder).measure(group, report, test) }
    assert_equal "stop boom", error.message
    assert_equal [[:stop, :raising], [:stop, :low], [:stop, :high]], LOG.reject { it == :wrap },
      "every collector is stopped, ascending .order, even after an earlier #stop raises"
  end
end
