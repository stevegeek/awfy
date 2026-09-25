# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "sqlite3"

class LabelFilterTest < Minitest::Test
  OLD_SCHEMA = <<~SQL
    CREATE TABLE results (id INTEGER PRIMARY KEY, result_id TEXT UNIQUE, control BOOLEAN DEFAULT 0,
      baseline BOOLEAN DEFAULT 0, type TEXT, group_name TEXT, report_name TEXT, test_name TEXT,
      runtime TEXT, timestamp INTEGER, branch TEXT, commit_hash TEXT, commit_message TEXT,
      ruby_version TEXT, result_data TEXT);
  SQL

  def setup
    @dir = Dir.mktmpdir
    @name = File.join(@dir, "store")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def measure(label, timestamp: 1_000)
    Awfy::MeasureResult.new(type: :measure, group_name: "G", report_name: "R", test_name: "t",
      runtime: "mri", timestamp:, run_label: label,
      result_data: {collectors: {"timing" => {"wall_s" => 1.0}}})
  end

  def sqlite = Awfy::Stores::Sqlite.new(storage_name: @name, retention_policy: Awfy::RetentionPolicies.keep_all)

  def test_measure_type_resolves
    assert_equal Awfy::MeasureResult, Awfy::Result.result_class(:measure)
  end

  def test_sqlite_saves_and_filters_by_label
    store = sqlite
    store.save_result(measure("a"))
    store.save_result(measure("b"))
    found = store.query_results(type: :measure, label: "a")
    assert_equal ["a"], found.map(&:run_label)
    assert_instance_of Awfy::MeasureResult, found.first
    assert_equal({"wall_s" => 1.0}, found.first.result_data[:collectors]["timing"])
  end

  def test_adds_the_label_column_to_an_old_store
    db = SQLite3::Database.new("#{@name}.db")
    db.execute(OLD_SCHEMA)
    db.execute("INSERT INTO results (result_id, type, group_name, report_name, test_name, runtime, timestamp, ruby_version, result_data) " \
      "VALUES ('old-1', 'memory', 'G', 'R', 't', 'mri', 1, '3.4.1', '{}')")
    db.close
    store = sqlite
    assert_nil store.load_result("old-1").run_label
    assert_empty store.query_results(label: "a")
    store.save_result(measure("a"))
    assert_equal 1, store.query_results(label: "a").size
  end

  def test_json_and_memory_stores_filter_by_label
    json = Awfy::Stores::Json.new(storage_name: File.join(@dir, "json"), retention_policy: Awfy::RetentionPolicies.keep_all)
    memory = Awfy::Stores::Memory.new(storage_name: "m", retention_policy: Awfy::RetentionPolicies.keep_all)
    [json, memory].each do |store|
      store.save_result(measure("a"))
      store.save_result(measure("b"))
      assert_equal ["b"], store.query_results(type: :measure, label: "b").map(&:run_label)
    end
  end
end
