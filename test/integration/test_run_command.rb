# frozen_string_literal: true

require_relative "integration_test_helper"

class RunCommandIntegrationTest < Minitest::Test
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

  def run_args(*extra, store: @store, backend: "sqlite")
    ["run", "measure/suite.rb", "--setup-file-path", "./measure/setup", "--store", store,
      "--storage-backend", backend, "--color", "off", *extra]
  end

  def test_run_writes_json_and_stores_one_result_per_test
    awfy(*run_args("--label", "base", "--collectors", "timing,gc,rss", "--format", "json", "--output", "out/base.json"))
    doc = JSON.parse(File.read(File.join(@test_dir, "out/base.json")))
    assert_equal "base", doc["label"]
    result = doc["results"].first
    assert_equal ["Fixture Measure", "#build", "strings"], result.values_at("group", "report", "test")
    assert_equal "none", result["isolation"]
    assert_equal({"items" => 1000}, result["outcome"])
    assert_equal %w[gc rss timing], result["collectors"].keys.sort
    assert File.exist?(@store), "--store names the SQLite file itself"
    stored = Awfy::Stores.sqlite(@store.delete_suffix(".db"), Awfy::RetentionPolicies.keep_all)
    assert_equal 1, stored.query_results(type: :measure, label: "base").size
  end

  def test_store_with_json_backend_names_the_result_directory
    store = File.join(@test_dir, "results")
    awfy(*run_args("--label", "base", "--collectors", "timing", "--format", "json", "--output", "out/base.json",
      store: store, backend: "json"))
    assert_equal 1, Dir.glob(File.join(store, "*#{Awfy::Stores::AWFY_RESULT_EXTENSION}")).size,
      "--store names the JSON result directory itself"
    refute File.exist?(@store), "the json backend must not write a SQLite file"
    stored = Awfy::Stores.json(store, Awfy::RetentionPolicies.keep_all)
    found = stored.query_results(type: :measure, label: "base")
    assert_equal [["Fixture Measure", "#build", "strings"]], found.map { [it.group_name, it.report_name, it.test_name] }
    assert_empty stored.query_results(type: :measure, label: "other")
  end

  def test_default_label_is_the_git_branch_and_table_format_prints
    output = awfy(*run_args("--collectors", "timing", "--format", "table"))
    refute_empty output.strip, "TableTennis may abbreviate cells to the terminal width; only check it printed"
    stored = Awfy::Stores.sqlite(@store.delete_suffix(".db"), Awfy::RetentionPolicies.keep_all)
    assert_equal ["main"], stored.query_results(type: :measure).map(&:run_label)
  end

  def test_a_failed_assertion_exits_1_and_still_stores_the_result
    File.write(File.join(@test_dir, "measure/asserting_suite.rb"), <<~RUBY)
      Awfy.group "Asserting" do
        isolate :none
        report "#sum" do
          assert "timing.wall_s" => ...0, "gc.minor_count" => ..1_000_000
          test("sum") { (1..100).sum }
        end
      end
    RUBY
    args = run_args("--label", "base", "--collectors", "timing", "--format", "json", "--output", "out/base.json")
    args[1] = "measure/asserting_suite.rb"
    _, err = capture_io do
      error = assert_raises(SystemExit) { awfy(*args) }
      assert_equal 1, error.status
    end
    assert_match(/1 test\(s\) failed/, err)
    doc = JSON.parse(File.read(File.join(@test_dir, "out/base.json")))
    message = doc["failures"].first["error"]
    assert_match(/\AAssertion failed: timing\.wall_s is [\d.e-]+, outside \.\.\.0; /, message)
    assert_match(/gc\.minor_count cannot be checked: the 'gc' collector did not run/, message)
    stored = Awfy::Stores.sqlite(@store.delete_suffix(".db"), Awfy::RetentionPolicies.keep_all)
    assert_equal ["sum"], stored.query_results(type: :measure, label: "base").map(&:test_name)
  end

  def test_unknown_collector_exits_with_the_known_list
    _, err = capture_io do
      assert_raises(SystemExit) { awfy(*run_args("--collectors", "timing,nope", "--format", "json")) }
    end
    assert_match(/Unknown collector 'nope'/, err)
  end

  def test_unknown_option_exits_with_a_message
    _, err = capture_io do
      assert_raises(SystemExit) { awfy(*run_args("--colectors", "timing")) }
    end
    assert_match(/Unknown switches/, err)
  end

  def test_store_locks_storage_backend_against_an_awfy_json_redirect
    File.write(File.join(@test_dir, ".awfy.json"), JSON.generate(storage_backend: "json"))
    awfy(*run_args("--collectors", "timing", "--format", "json", "--output", "out/base.json"))
    assert File.exist?(@store), "--store's sqlite backend must win over .awfy.json's storage_backend"
    stored = Awfy::Stores.sqlite(@store.delete_suffix(".db"), Awfy::RetentionPolicies.keep_all)
    assert_equal 1, stored.query_results(type: :measure).size
  end
end
