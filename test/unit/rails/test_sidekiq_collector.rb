# frozen_string_literal: true

require "test_helper"
require "awfy/rails"

class SidekiqCollectorTest < Minitest::Test
  class FakeApi
    attr_accessor :queue_data, :scheduled

    def initialize
      @queue_data = {"default" => ["A"]}
      @scheduled = 0
    end

    def queues = queue_data.transform_values(&:dup)

    def scheduled_size = scheduled
  end

  def setup
    @api = FakeApi.new
    Awfy::Rails::Collectors::Sidekiq.api = @api
  end

  def teardown
    Awfy::Rails::Collectors::Sidekiq.api = nil
  end

  def test_enqueued_deltas_by_class_and_queue
    context = Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass: 1, artefacts_dir: Dir.tmpdir)
    collector = Awfy::Rails::Collectors::Sidekiq.new
    collector.start(context)
    @api.queue_data = {"default" => %w[A B B], "priority" => ["C"]}
    @api.scheduled = 2
    data = collector.stop(context)
    assert_equal({"total" => 3, "by_class" => {"B" => 2, "C" => 1}, "by_queue" => {"default" => 2, "priority" => 1}, "scheduled" => 2}, data)
    assert_equal data, Awfy::Rails::Collectors::Sidekiq.outcome(data)
    assert_nil Awfy::Rails::Collectors::Sidekiq.outcome(nil)
  end
end
