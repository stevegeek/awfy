# frozen_string_literal: true

require_relative "rails_test_helper"
require "warden"

class RailsHelpersTest < Minitest::Test
  class FakeJob
    def perform(queue_data, name)
      queue_data["default"] << name
    end
  end

  class FakeJobWithKwargs
    def perform(queue_data, name, priority:)
      queue_data["default"] << "#{name}:#{priority}"
    end
  end

  class FakeApi
    attr_reader :queue_data

    def initialize = @queue_data = {"default" => []}

    def queues = queue_data.transform_values(&:dup)

    def scheduled_size = 0
  end

  def teardown
    Awfy::Rails.app = nil
    Awfy::Rails::Collectors::Sidekiq.api = nil
    Awfy::Outcome.reset!
  end

  def test_request_records_status_and_body_bytes
    Awfy::Rails.app = ->(env) { [(env["HTTP_HOST"] == "js.example.test") ? 200 : 404, {"content-type" => "text/plain"}, ["hello"]] }
    response = Awfy::Suite.new.request(:get, "/pub_1/settings", host: "js.example.test")
    assert_equal 200, response.status
    assert_equal({"status" => 200, "body_bytes" => 5}, Awfy::Outcome.resolve(nil, {}))
  end

  def test_request_outside_expect_raises
    Awfy::Rails.app = ->(_env) { [404, {}, ["no"]] }
    error = assert_raises(Awfy::UnexpectedStatus) { Awfy::Suite.new.request(:get, "/x", host: "h.test") }
    assert_match(/GET h\.test\/x returned 404/, error.message)
    assert_nil Awfy::Outcome.resolve(nil, {})
  end

  def test_request_expect_accepts_a_single_status
    Awfy::Rails.app = ->(_env) { [200, {}, ["ok"]] }
    response = Awfy::Suite.new.request(:get, "/", host: "h.test", expect: 200)
    assert_equal 200, response.status
  end

  def test_request_as_logs_in_through_warden
    inner = ->(env) { [200, {}, [env["warden"].user(:user).to_s]] }
    Awfy::Rails.app = Warden::Manager.new(inner)
    assert_equal "user-7", Awfy::Suite.new.request(:get, "/", host: "h.test", as: "user-7").body
  end

  def test_request_as_uses_the_fetch_event_not_authentication
    events = []
    ::Warden::Manager.after_set_user { |_user, _proxy, opts| events << opts[:event] }
    inner = ->(env) { [200, {}, [env["warden"].user(:user).to_s]] }
    Awfy::Rails.app = Warden::Manager.new(inner)
    Awfy::Suite.new.request(:get, "/", host: "h.test", as: "user-7")
    assert_equal [:fetch], events
  ensure
    ::Warden::Manager._after_set_user.pop
  end

  def test_request_as_clears_the_warden_queue_even_when_the_app_never_reaches_warden
    Awfy::Rails.app = ->(_env) { [200, {}, ["ok"]] }
    Awfy::Suite.new.request(:get, "/", host: "h.test", as: "user-7")
    assert_empty ::Warden._on_next_request
  end

  def test_perform_job_outcome_is_the_enqueued_summary
    api = FakeApi.new
    Awfy::Rails::Collectors::Sidekiq.api = api
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJob, api.queue_data, "Hubspot::Import") } }
    end
    group = suite.groups.first
    runner = Awfy::PassRunner.new(collectors: [Awfy::Rails::Collectors::Sidekiq], label: "l", artefacts_dir: Dir.tmpdir)
    # The collector-less warm-up pass (pass 0) calls perform_job too, and always has no sidekiq
    # collector instance, by design, regardless of the run's configuration; this run IS
    # configured with the sidekiq collector, so no warning is expected from either pass.
    measurement = nil
    _, err = capture_io { measurement = runner.measure(group, group.reports.first, group.reports.first.tests.first) }
    assert_empty err, "a correctly configured run must not warn, even from the warm-up pass"
    assert_equal({"total" => 1, "by_class" => {"Hubspot::Import" => 1}, "by_queue" => {"default" => 1}, "scheduled" => 0}, measurement.outcome)
  end

  def test_perform_job_outcome_is_nil_without_the_sidekiq_collector
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJob, {"default" => []}, "X") } }
    end
    group = suite.groups.first
    runner = Awfy::PassRunner.new(collectors: [], label: "l", artefacts_dir: Dir.tmpdir)
    measurement = nil
    capture_io { measurement = runner.measure(group, group.reports.first, group.reports.first.tests.first) }
    assert_nil measurement.outcome
  end

  def test_perform_job_warns_once_to_stderr_when_the_sidekiq_collector_is_not_active
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJob, {"default" => []}, "X") } }
    end
    group = suite.groups.first
    # sidekiq is not in this run's collectors at all: warm-up (pass 0) and the light pass (pass
    # 1) both call perform_job, so a single #measure already proves "once", not "once per pass".
    runner = Awfy::PassRunner.new(collectors: [], label: "l", artefacts_dir: Dir.tmpdir)
    _, err = capture_io { runner.measure(group, group.reports.first, group.reports.first.tests.first) }
    assert_equal 1, err.scan("sidekiq collector, which is not active").size
  end

  def test_perform_job_does_not_warn_for_the_warm_up_pass_when_sidekiq_is_configured_for_the_run
    Awfy::Rails::Collectors::Sidekiq.api = FakeApi.new
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJob, {"default" => []}, "X") } }
    end
    group = suite.groups.first
    # The warm-up pass (pass 0) always runs with no collector instances, by design, even though
    # sidekiq IS configured for this run (it is only instantiated from pass 1 on). The warning
    # must be driven by the run's configured collectors (PassRunner#collector_key?), not by
    # whether any one pass's instances happen to include it.
    runner = Awfy::PassRunner.new(collectors: [Awfy::Rails::Collectors::Sidekiq], label: "l", artefacts_dir: Dir.tmpdir)
    _, err = capture_io { runner.measure(group, group.reports.first, group.reports.first.tests.first) }
    assert_empty err
  end

  def test_perform_job_warns_once_per_run_not_once_per_process
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJob, {"default" => []}, "X") } }
    end
    group = suite.groups.first
    test = group.reports.first.tests.first
    # Two separate runs (two PassRunner instances), each without sidekiq configured: each must
    # warn on its own, not have the second masked by the first's already having warned.
    first_run = Awfy::PassRunner.new(collectors: [], label: "l", artefacts_dir: Dir.tmpdir)
    second_run = Awfy::PassRunner.new(collectors: [], label: "l", artefacts_dir: Dir.tmpdir)
    _, err = capture_io do
      first_run.measure(group, group.reports.first, test)
      second_run.measure(group, group.reports.first, test)
    end
    assert_equal 2, err.scan("sidekiq collector, which is not active").size
  end

  def test_perform_job_passes_keyword_arguments
    api = FakeApi.new
    Awfy::Rails::Collectors::Sidekiq.api = api
    suite = Awfy::Suite.new
    suite.group("G") do
      isolate :none
      report("R") { test("t") { perform_job(FakeJobWithKwargs, api.queue_data, "X", priority: "high") } }
    end
    group = suite.groups.first
    runner = Awfy::PassRunner.new(collectors: [Awfy::Rails::Collectors::Sidekiq], label: "l", artefacts_dir: Dir.tmpdir)
    # Warm-up (pass 0, no collectors) and the light pass (pass 1, with the sidekiq collector)
    # each call the job once; both must thread the keyword argument through the same way, and
    # neither should warn, since this run IS configured with the sidekiq collector.
    _, err = capture_io { runner.measure(group, group.reports.first, group.reports.first.tests.first) }
    assert_empty err
    assert_equal ["X:high", "X:high"], api.queue_data["default"]
  end
end
