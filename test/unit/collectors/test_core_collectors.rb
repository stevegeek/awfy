# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CoreCollectorsTest < Minitest::Test
  def context(pass = 1)
    Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass:, artefacts_dir: Dir.tmpdir)
  end

  def measure(collector, &block)
    value = collector.around(context) do
      collector.start(context)
      block.call
    end
    [value, collector.stop(context)]
  end

  def test_timing
    _, data = measure(Awfy::Collectors::Timing.new) { sleep 0.01 }
    assert_operator data["wall_s"], :>=, 0.01
    assert_operator data["cpu_s"], :>=, 0.0
    assert_equal(-100, Awfy::Collectors::Timing.order)
  end

  def test_gc_counts_allocations
    _, data = measure(Awfy::Collectors::Gc.new) { Array.new(10_000) { Object.new } }
    assert_operator data["total_allocated_objects"], :>=, 10_000
    assert data.key?("malloc_increase_bytes")
  end

  def test_rss_reads_the_process_and_stops_last
    _, data = measure(Awfy::Collectors::Rss.new) { "x" * 1_000_000 }
    assert_operator data["before_mb"], :>, 0
    assert data.key?("after_gc_mb")
    assert_equal 100, Awfy::Collectors::Rss.order
  end

  def test_memory_profiler_is_heavy_and_returns_totals_and_lists
    assert Awfy::Collectors::MemoryProfiler.heavy?
    value, data = measure(Awfy::Collectors::MemoryProfiler.new) do
      Array.new(2_000) { |i| "string-#{i}" }
      :done
    end
    assert_equal :done, value
    assert_operator data["allocated_objects"], :>=, 2_000
    assert_operator data["allocated_memsize"], :>, 0
    assert_operator data["allocated_memory_by_location"].size, :<=, 25
    assert_equal %w[count data], data["allocated_memory_by_location"].first.keys.sort
    assert_equal %w[allocated_memsize allocated_objects retained_memsize retained_objects],
      Awfy::Collectors::MemoryProfiler.metrics(data).keys.sort
  end

  def test_memory_profiler_stop_returns_an_empty_hash_when_around_never_completed
    assert_equal({}, Awfy::Collectors::MemoryProfiler.new.stop(context))
  end

  def test_memory_profiler_extras_list_the_baseline_top_sites
    base = {"allocated_memory_by_location" => (1..20).map { {"data" => "f.rb:#{it}", "count" => 100 - it} }}
    other = {"allocated_memory_by_location" => [{"data" => "f.rb:1", "count" => 7}]}
    sites = Awfy::Collectors::MemoryProfiler.extras(base, other)["allocation_sites"]
    assert_equal 15, sites.size
    assert_equal({"location" => "f.rb:1", "baseline" => 99, "against" => 7}, sites.first)
    assert_nil sites.last["against"]
  end
end
