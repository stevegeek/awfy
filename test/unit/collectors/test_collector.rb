# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CollectorTest < Minitest::Test
  def test_default_compare_takes_the_union_and_treats_missing_as_zero
    rows = Awfy::Collector.compare({"a" => 10, "b" => 4, "s" => "text"}, {"a" => 15, "c" => 2})
    assert_equal({"base" => 10, "other" => 15, "delta" => 5, "pct" => 50.0}, rows["a"])
    assert_equal({"base" => 4, "other" => 0, "delta" => -4, "pct" => -100.0}, rows["b"])
    assert_nil rows["c"]["pct"], "no percentage against a zero baseline"
    refute rows.key?("s"), "non-numeric values are not metrics"
  end

  def test_delta_row_with_a_nil_value
    assert_equal({"base" => nil, "other" => 3, "delta" => nil, "pct" => nil}, Awfy::Collector.delta_row(nil, 3))
  end

  def test_context_artefact_path_creates_the_directory
    Dir.mktmpdir do |dir|
      context = Awfy::CollectorContext.new(group_name: "G/1", report_name: "#r", test_name: "t t",
        label: "l", pass: 2, artefacts_dir: File.join(dir, "a"))
      path = context.artefact_path("vernier.json.gz")
      assert_equal File.join(dir, "a", "G_1-_r-t_t.vernier.json.gz"), path
      assert Dir.exist?(File.join(dir, "a"))
    end
  end
end
