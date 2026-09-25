# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ComparisonTest < Minitest::Test
  def setup
    @store = Awfy::Stores::Memory.new(storage_name: "m", retention_policy: Awfy::RetentionPolicies.keep_all)
  end

  META = {"ruby" => "ruby 3.4.1", "yjit" => false, "awfy" => "1.0.0"}.freeze

  def save(label, group_name: "G", test_name: "t", timestamp: 1_000, wall: 1.0, outcome: {"n" => 1}, extra: {},
    isolation: "transaction", runtime: "mri", meta: META)
    result_data = {isolation:, outcome:, collectors: {"timing" => {"wall_s" => wall, "cpu_s" => 0.5}}.merge(extra)}
    result_data[:meta] = meta if meta
    @store.save_result(Awfy::MeasureResult.new(
      type: :measure, group_name:, report_name: "R", test_name:, runtime:, timestamp:, run_label: label, result_data:
    ))
  end

  def compare(group_names: nil) = Awfy::Comparison.new(store: @store, baseline: "a", against: "b", group_names:).call

  def test_rows_for_tests_under_both_labels
    save("a", wall: 2.0)
    save("b", wall: 1.0)
    result = compare["results"].first
    assert_equal({"base" => 2.0, "other" => 1.0, "delta" => -1.0, "pct" => -50.0}, result["collectors"]["timing"]["metrics"]["wall_s"])
    refute result["outcome_differs"]
    assert_equal({"baseline" => "transaction", "against" => "transaction"}, result["isolation"])
  end

  def test_latest_result_per_label_wins
    save("a", wall: 9.0, timestamp: 100)
    save("a", wall: 2.0, timestamp: 200)
    save("b", wall: 1.0)
    assert_equal 2.0, compare["results"].first["collectors"]["timing"]["metrics"]["wall_s"]["base"]
  end

  def test_outcome_differs
    save("a", outcome: {"n" => 11})
    save("b", outcome: {"n" => 0})
    assert compare["results"].first["outcome_differs"]
  end

  def test_outcome_recorded_is_true_when_at_least_one_label_recorded_one
    save("a", outcome: {"n" => 11})
    save("b", outcome: nil)
    assert compare["results"].first["outcome_recorded"]
  end

  def test_outcome_recorded_is_false_when_neither_label_recorded_one
    save("a", outcome: nil)
    save("b", outcome: nil)
    result = compare["results"].first
    refute result["outcome_recorded"], "neither label recorded an outcome"
    refute result["outcome_differs"], "nil == nil: not a difference, just nothing recorded"
  end

  def test_missing_tests_are_listed
    save("a")
    save("a", test_name: "only_a")
    save("b")
    assert_equal [{"group" => "G", "report" => "R", "test" => "only_a", "only_in" => "a"}], compare["missing"]
  end

  def test_unknown_label_raises_with_the_label
    save("a")
    error = assert_raises(Awfy::Errors::LabelNotFoundError) { compare }
    assert_match(/'b'/, error.message)
  end

  def test_group_names_restricts_the_comparison_to_the_listed_groups
    save("a", group_name: "G1")
    save("b", group_name: "G1")
    save("a", group_name: "G2", test_name: "only_g2")
    result = compare(group_names: ["G1", "G3"])
    assert_equal ["G1"], result["results"].map { it["group"] }
    assert_empty result["missing"], "G2, outside the group filter, must not be listed as missing"
  end

  def test_group_names_keeps_the_single_name_form_working
    save("a", group_name: "G1")
    save("b", group_name: "G1")
    save("a", group_name: "G2")
    save("a", group_name: "G2", test_name: "only_a")
    result = compare(group_names: ["G1"])
    assert_equal ["G1"], result["results"].map { it["group"] }
    assert_empty result["missing"]
  end

  def test_extras_come_from_the_collector_class
    sites = {"allocated_memory_by_location" => [{"data" => "x.rb:1", "count" => 10}], "allocated_memsize" => 10}
    save("a", extra: {"memory_profiler" => sites})
    save("b", extra: {"memory_profiler" => sites.merge("allocated_memsize" => 5)})
    collector = compare["results"].first["collectors"]["memory_profiler"]
    assert_equal(-50.0, collector["metrics"]["allocated_memsize"]["pct"])
    assert_equal [{"location" => "x.rb:1", "baseline" => 10, "against" => 10}], collector["extras"]["allocation_sites"]
  end

  def test_collectors_under_one_label_only_are_listed
    save("a", extra: {"sql" => {"queries" => 3}})
    save("b", extra: {"cache" => {"hits" => 1}})
    result = compare["results"].first
    assert_equal ["timing"], result["collectors"].keys
    assert_equal({"cache" => "b", "sql" => "a"}, result["collectors_missing"])
  end

  def test_collectors_missing_is_empty_when_both_labels_have_the_same_collectors
    save("a")
    save("b")
    assert_equal({}, compare["results"].first["collectors_missing"])
  end

  def test_no_warnings_when_the_environment_matches
    save("a")
    save("b")
    assert_equal [], compare["results"].first["warnings"]
  end

  def test_warns_when_isolation_differs
    save("a", isolation: "transaction")
    save("b", isolation: "none")
    assert_equal [{"field" => "isolation", "baseline" => "transaction", "against" => "none"}], compare["results"].first["warnings"]
  end

  def test_warns_when_runtime_differs
    save("a", runtime: "mri")
    save("b", runtime: "yjit", meta: META.merge("yjit" => true))
    assert_equal [
      {"field" => "runtime", "baseline" => "mri", "against" => "yjit"},
      {"field" => "yjit", "baseline" => false, "against" => true}
    ], compare["results"].first["warnings"]
  end

  def test_warns_for_each_meta_field_that_differs
    save("a", meta: META.merge("rails" => "8.0.1", "jemalloc" => true))
    save("b", meta: META.merge("ruby" => "ruby 3.4.2", "jemalloc" => false))
    assert_equal [
      {"field" => "jemalloc", "baseline" => true, "against" => false},
      {"field" => "rails", "baseline" => "8.0.1", "against" => nil},
      {"field" => "ruby", "baseline" => "ruby 3.4.1", "against" => "ruby 3.4.2"}
    ], compare["results"].first["warnings"]
  end

  def test_meta_warnings_ignore_the_pid
    save("a", meta: META.merge("pid" => 1))
    save("b", meta: META.merge("pid" => 2))
    assert_equal [], compare["results"].first["warnings"]
  end

  def test_results_without_meta_do_not_warn
    save("a", meta: nil)
    save("b")
    assert_equal [], compare["results"].first["warnings"]
  end

  def test_meta_warnings_work_after_a_json_round_trip
    Dir.mktmpdir do |dir|
      @store = Awfy::Stores.json(dir, Awfy::RetentionPolicies.keep_all)
      save("a")
      save("b", meta: META.merge("ruby" => "ruby 3.4.2"))
      assert_equal [{"field" => "ruby", "baseline" => "ruby 3.4.1", "against" => "ruby 3.4.2"}], compare["results"].first["warnings"]
    end
  end
end
