# frozen_string_literal: true

require_relative "integration_test_helper"

class RunAndCompareTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
    @store = File.join(@test_dir, "awfy.db")
  end

  def teardown
    ENV.delete("AWFY_FIXTURE_ITEMS")
    teardown_test_environment
  end

  def awfy(*argv) = capture_command_output { Awfy::CLI.start(argv) }

  def run_label(label, items)
    ENV["AWFY_FIXTURE_ITEMS"] = items.to_s
    awfy("run", "measure/suite.rb", "--setup-file-path", "./measure/setup", "--label", label, "--store", @store,
      "--storage-backend", "sqlite", "--collectors", "timing,gc,memory_profiler", "--vernier",
      "--artefacts", "art/#{label}", "--format", "json", "--output", "out/#{label}.json", "--color", "off")
  end

  def compare(format)
    awfy("compare", "--store", @store, "--storage-backend", "sqlite", "--baseline", "base", "--against", "other",
      "--format", format, "--output", "out/compare.#{format}", "--color", "off")
    File.read(File.join(@test_dir, "out/compare.#{format}"))
  end

  def test_run_twice_then_compare
    run_label("base", 1_000)
    run_label("other", 4_000)
    doc = JSON.parse(compare("json"))
    result = doc["results"].first
    assert_equal "strings", result["test"]
    assert result["outcome_differs"], "items 1000 vs 4000"
    memory = result["collectors"]["memory_profiler"]
    assert_operator memory["metrics"]["allocated_objects"]["delta"], :>, 0
    assert_operator memory["extras"]["allocation_sites"].size, :>, 0
    assert_equal %w[gc memory_profiler timing vernier], result["collectors"].keys.sort
    assert_empty doc["missing"]
    assert_equal({}, result["collectors_missing"])
    assert_equal [], result["warnings"], "both runs share one process, so the environment matches"
    assert Dir.glob(File.join(@test_dir, "art/base/*.vernier.json.gz")).any?

    md = compare("md")
    assert_includes md, "| memory_profiler | allocated_objects |"
    assert_includes md, "**Outcome differs**"
  end

  def test_compare_with_an_unknown_label_exits
    run_label("base", 1_000)
    _, err = capture_io { assert_raises(SystemExit) { compare("json") } }
    assert_match(/label 'other'/, err)
  end

  def test_compare_with_an_unknown_option_exits_with_a_message
    run_label("base", 1_000)
    _, err = capture_io do
      assert_raises(SystemExit) do
        awfy("compare", "--store", @store, "--storage-backend", "sqlite", "--baseline", "base", "--against", "other",
          "--colectors", "timing")
      end
    end
    assert_match(/Unknown switches/, err)
  end
end
