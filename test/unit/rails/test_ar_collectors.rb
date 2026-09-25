# frozen_string_literal: true

require_relative "rails_test_helper"

class ArCollectorsTest < Minitest::Test
  include RailsTestHelper

  def setup
    RailsTestHelper.connect!
    AwfyWidget.delete_all
    3.times { AwfyWidget.create!(name: "w#{it}") }
  end

  def test_instantiation_by_class
    data = collect(Awfy::Rails::Collectors::Instantiation.new) { AwfyWidget.all.to_a }
    assert_equal({"total" => 3, "by_class" => {"AwfyWidget" => 3}}, data)
    rows = Awfy::Rails::Collectors::Instantiation.compare(data, {"total" => 1, "by_class" => {"Other" => 1}})
    assert_equal(-3, rows["AwfyWidget"]["delta"])
    assert_equal 1, rows["Other"]["other"]
  end

  def test_cache_hits_misses_writes
    store = ActiveSupport::Cache::MemoryStore.new
    data = collect(Awfy::Rails::Collectors::Cache.new) do
      store.read("a")
      store.write("a", 1)
      store.read("a")
      store.read_multi("a", "b")
    end
    assert_equal({"reads" => 4, "hits" => 2, "misses" => 2, "writes" => 1}, data)
  end

  def test_cache_counts_identity_cache_events_when_they_occur
    data = collect(Awfy::Rails::Collectors::Cache.new) do
      identity_cache_fetch("cache_fetch.identity_cache", keys: 1, memo_misses: 1, cache_misses: 0)
      identity_cache_fetch("cache_fetch_multi.identity_cache", keys: 3, memo_misses: 2, cache_misses: 1, resolve_miss_time: 0.0025)
      notify("cache_write.identity_cache", memoizing: false)
      notify("cache_delete.identity_cache", memoizing: false)
      notify("cache_delete_multi.identity_cache", memoizing: false)
      2.times { notify("hydration.identity_cache", class: "AwfyWidget") }
      notify("dehydration.identity_cache", class: "AwfyWidget")
      notify("cache_cas.active_support", key: "blob:1")
      notify("cache_cas_multi.active_support", key: ["blob:2", "blob:3"])
    end
    assert_equal(
      {
        "reads" => 0, "hits" => 0, "misses" => 0, "writes" => 0, "cas" => 3,
        "identity_cache_fetches" => 2, "identity_cache_keys" => 4, "identity_cache_memo_hits" => 1,
        "identity_cache_hits" => 2, "identity_cache_misses" => 1, "identity_cache_resolve_miss_ms" => 2.5,
        "identity_cache_writes" => 1, "identity_cache_deletes" => 2, "identity_cache_hydrations" => 2
      },
      data
    )
  end

  private

  def notify(name, payload) = ActiveSupport::Notifications.instrument(name, payload) {}

  # IdentityCache fills the fetch payload inside the instrumented block, after the lookup.
  def identity_cache_fetch(name, keys:, memo_misses:, cache_misses:, resolve_miss_time: 0.0)
    ActiveSupport::Notifications.instrument(name) do |payload|
      payload[:resolve_miss_time] = resolve_miss_time
      payload[:memoizing] = false
      payload[:memo_hits] = keys - memo_misses
      payload[:cache_hits] = memo_misses - cache_misses
      payload[:cache_misses] = cache_misses
    end
  end
end
