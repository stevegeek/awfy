# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "awfy/rails"

class ElasticsearchCollectorTest < Minitest::Test
  Collector = Awfy::Rails::Collectors::Elasticsearch

  # Stands in for Elastic::Transport::Client. Each test instruments its own subclass, so a
  # prepend in one test never leaks into another.
  class FakeTransport
    attr_reader :calls

    def initialize
      @calls = []
    end

    def perform_request(method, path, params = {}, body = nil, headers = nil, opts = {})
      @calls << [method, path, params, body, headers, opts]
      :response
    end
  end

  def setup
    @klass = Class.new(FakeTransport)
    Collector.target = @klass
  end

  def teardown
    Collector.target = nil
    Thread.current[Collector::ACTIVE_KEY] = nil
  end

  def context
    Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass: 1, artefacts_dir: Dir.tmpdir)
  end

  def collect
    collector = Collector.new
    collector.start(context)
    yield
    collector.stop(context)
  end

  def test_counts_requests_by_method_and_normalized_path
    client = @klass.new
    data = collect do
      client.perform_request("GET", "orders_production_20260924120000123/_search", {size: 0}, {query: {}})
      client.perform_request("GET", "orders_production_20260924120000123/_search")
      client.perform_request("POST", "_bulk", {}, "{}\n")
    end
    assert_equal 3, data["requests"]
    assert_equal({"GET /orders_production_*/_search" => 2, "POST /_bulk" => 1}, data["by_path"])
    assert_equal true, data["transport"]
  end

  def test_forwards_every_argument_and_the_return_value
    client = @klass.new
    result = nil
    collect { result = client.perform_request("PUT", "idx/_doc/7", {refresh: true}, {a: 1}, {"X" => "y"}, {timeout: 1}) }
    assert_equal :response, result
    assert_equal [["PUT", "idx/_doc/7", {refresh: true}, {a: 1}, {"X" => "y"}, {timeout: 1}]], client.calls
  end

  def test_ignores_requests_outside_a_collector_and_on_other_threads
    client = @klass.new
    Collector.install!
    client.perform_request("GET", "_cluster/health")
    data = collect { Thread.new { client.perform_request("GET", "idx/_search") }.join }
    assert_equal 0, data["requests"]
    assert_equal 2, client.calls.size
  end

  def test_prepends_once
    3.times { Collector.install! }
    assert_equal 1, @klass.ancestors.count(Collector::Instrumentation)
  end

  def test_is_inert_without_a_transport_class
    Collector.target = nil
    data = collect {}
    assert_equal({"requests" => 0, "by_path" => {}, "transport" => false}, data)
  end

  def test_restores_the_previous_collector
    outer = Collector.new
    outer.start(context)
    inner = Collector.new
    inner.start(context)
    inner.stop(context)
    assert_same outer, Collector.current
    outer.stop(context)
    assert_nil Collector.current
  end

  def test_normalize_path
    assert_equal "/", Collector.normalize_path("")
    assert_equal "/", Collector.normalize_path("/")
    assert_equal "/idx/_doc/:id", Collector.normalize_path("/idx/_doc/abc123")
    assert_equal "/idx/_update/:id", Collector.normalize_path("idx/_update/9")
    assert_equal "/a,b/_search", Collector.normalize_path("a,b/_search?scroll=1m")
    assert_equal "/_cluster/health", Collector.normalize_path("_cluster/health")
  end

  def test_metrics_for_compare
    data = {"requests" => 3, "by_path" => {"POST /_bulk" => 1}, "transport" => true}
    assert_equal({"requests" => 3, "POST /_bulk" => 1}, Collector.metrics(data))
  end

  def test_is_registered
    assert_equal Collector, Awfy::Collectors.fetch("elasticsearch")
  end
end
