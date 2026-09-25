# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class RunCommandTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, "setup.rb"), "# nothing\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def session
    config = Awfy::Config.new(setup_file_path: File.join(@dir, "setup"), tests_path: @dir, storage_backend: "memory")
    @store = Awfy::Stores.memory("m", Awfy::RetentionPolicies.keep_all)
    Awfy::Session.new(shell: Awfy::Shell.new(config:), config:, git_client: Awfy::GitClient.new(path: @dir), results_store: @store)
  end

  def write_suite(body)
    path = File.join(@dir, "suite_#{rand(1_000_000)}.rb")
    File.write(path, body)
    path
  end

  def run_command(path, keys: ["timing"], label: "l")
    Awfy::Commands::Run.new(session:, suite_path: path, label:, collector_keys: keys, artefacts_dir: File.join(@dir, "art")).run
  end

  def test_failing_test_is_listed_and_others_are_saved
    path = write_suite(<<~RUBY)
      Awfy.group "G" do
        isolate :none
        report "R" do
          test("ok") { 1 + 1 }
          alternative("bad") { raise ArgumentError, "nope" }
        end
      end
    RUBY
    doc = run_command(path)
    assert_equal ["ok"], doc["results"].map { it["test"] }
    assert_equal [{"group" => "G", "report" => "R", "test" => "bad", "error" => "ArgumentError: nope"}], doc["failures"]
    saved = @store.query_results(type: :measure, label: "l")
    assert_equal ["ok"], saved.map(&:test_name)
    assert_equal "none", saved.first.result_data[:isolation]
  end

  def test_saved_results_carry_the_run_meta
    File.write(File.join(@dir, "setup.rb"), %(Awfy::RunMeta.merge!("rails_env" => "test")\n))
    path = write_suite(%(Awfy.group("G") { isolate :none; report("R") { test("t") { 1 } } }\n))
    run_command(path)
    meta = @store.query_results(type: :measure, label: "l").first.result_data[:meta]
    assert_equal RUBY_DESCRIPTION, meta["ruby"]
    assert_equal Awfy::VERSION, meta["awfy"]
    assert_equal "test", meta["rails_env"], "meta is taken after the setup file ran"
    refute meta.key?("pid"), "the pid differs on every run, so it is not stored with results"
  ensure
    Awfy::RunMeta.reset!
  end

  def test_unknown_collector_raises_before_any_call
    marker = File.join(@dir, "called")
    path = write_suite(%(Awfy.group("G") { report("R") { test("t") { File.write(#{marker.inspect}, "x") } } }\n))
    assert_raises(Awfy::Errors::UnknownCollectorError) { run_command(path, keys: ["timing", "sql_typo"]) }
    refute File.exist?(marker)
  end

  def test_unavailable_isolation_raises_before_any_call
    marker = File.join(@dir, "called")
    path = write_suite(<<~RUBY)
      Awfy.group "G" do
        isolate :none
        report("R") { test("t") { File.write(#{marker.inspect}, "x") } }
      end
      Awfy.group "H" do
        isolate :transaction
        report("R") { test("u") {} }
      end
    RUBY
    # Forces :transaction to be unregistered for this test regardless of whether another test
    # file already required "awfy/rails" (which registers it process-wide).
    saved = Awfy::Isolation.strategies.dup
    Awfy::Isolation.instance_variable_set(:@strategies, {none: Awfy::Isolation::None, snapshot: Awfy::Isolation::None})
    assert_raises(Awfy::Errors::IsolationUnavailableError) { run_command(path) }
    refute File.exist?(marker), "isolation for every selected test is resolved before the first call, like Collectors.fetch"
  ensure
    Awfy::Isolation.instance_variable_set(:@strategies, saved) if saved
  end

  def test_a_suite_file_loads_into_a_fresh_suite_each_run
    path = write_suite(%(Awfy.group("Only Here") { isolate(:none); report("R") { test("t") {} } }\n))
    # A group in the global suite (as other suites leave behind) must not run; isolated_suite
    # keeps this test's leftover out of the real global suite.
    Awfy.isolated_suite do
      Awfy.group("Global Leftover") { report("R") { test("t") {} } }
      2.times { assert_equal ["Only Here"], run_command(path)["results"].map { it["group"] }.uniq }
    end
  end

  def test_failed_assertions_list_the_test_under_failures_and_keep_the_result
    path = write_suite(<<~RUBY)
      Awfy.group "G" do
        isolate :none
        assert "timing.wall_s" => ..60
        report "R" do
          assert "timing.cpu_s" => ..-1, "sql.queries" => 5
          test("slow") { 1 + 1 }
        end
        report("S") { test("fast") { 1 + 1 } }
      end
    RUBY
    doc = run_command(path)
    assert_equal ["slow", "fast"], doc["results"].map { it["test"] }
    assert_equal 1, doc["failures"].size
    failure = doc["failures"].first
    assert_equal ["G", "R", "slow"], failure.values_at("group", "report", "test")
    cpu = doc["results"].first.dig("collectors", "timing", "cpu_s")
    assert_equal "Assertion failed: timing.cpu_s is #{cpu}, outside ..-1; " \
      "sql.queries cannot be checked: the 'sql' collector did not run (add it with --collectors)", failure["error"]
    assert_equal ["slow", "fast"], @store.query_results(type: :measure, label: "l").map(&:test_name)
  end

  def test_default_label_without_git_is_unlabelled
    path = write_suite(%(Awfy.group("G") { isolate(:none); report("R") { test("t") {} } }\n))
    assert_equal "unlabelled", run_command(path, label: nil)["label"]
  end
end
