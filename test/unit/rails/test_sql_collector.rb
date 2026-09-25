# frozen_string_literal: true

require_relative "rails_test_helper"
require "active_support/backtrace_cleaner"

class SqlCollectorTest < Minitest::Test
  include RailsTestHelper

  def setup
    RailsTestHelper.connect!
    AwfyWidget.delete_all
    3.times { AwfyWidget.create!(name: "w#{it}") }
    Awfy::Rails::Collectors::Sql.frame_finder = ->(stack) { stack.find { it.include?("test_sql_collector.rb") }&.sub(/\A.*\/test\//, "test/") }
  end

  def teardown
    Awfy::Rails::Collectors::Sql.frame_finder = nil
  end

  def test_counts_queries_cached_queries_and_n_plus_one
    data = collect(Awfy::Rails::Collectors::Sql.new) do
      6.times { |i| AwfyWidget.where(id: i).first }
      AwfyWidget.uncached { AwfyWidget.count }
      AwfyWidget.cache do
        AwfyWidget.where(name: "w1").to_a
        AwfyWidget.where(name: "w1").to_a
      end
    end
    assert_equal 8, data["queries"]
    assert_equal 1, data["cached"]
    candidate = data["n_plus_one"].first
    assert_equal 6, candidate["count"]
    assert_match(/test_sql_collector\.rb:\d+/, candidate["frame"])
    assert_match(/WHERE "awfy_widgets"\."id" = \?/, candidate["sql"])
    assert_equal 1, data["n_plus_one"].size
  end

  def test_unsubscribes_at_stop
    collector = Awfy::Rails::Collectors::Sql.new
    data = collect(collector) { AwfyWidget.first }
    AwfyWidget.first
    assert_equal 1, data["queries"]
    assert_equal 1, collector.stop(context)["queries"], "a second stop sees no new queries"
  end

  def test_extras_ignore_line_moves
    base = {"n_plus_one" => [{"sql" => "S", "frame" => "app/jobs/x.rb:11:in 'perform'", "count" => 9}, {"sql" => "T", "frame" => "app/y.rb:1", "count" => 5}]}
    other = {"n_plus_one" => [{"sql" => "S", "frame" => "app/jobs/x.rb:14:in 'perform'", "count" => 9}]}
    extras = Awfy::Rails::Collectors::Sql.extras(base, other)
    assert_equal ["T"], extras["n_plus_one_gone"].map { it["sql"] }
    assert_empty extras["n_plus_one_new"]
  end

  def test_threshold_from_env
    ENV["AWFY_N_PLUS_ONE_THRESHOLD"] = "7"
    data = collect(Awfy::Rails::Collectors::Sql.new) { 6.times { |i| AwfyWidget.where(id: i).first } }
    assert_empty data["n_plus_one"]
  ensure
    ENV.delete("AWFY_N_PLUS_ONE_THRESHOLD")
  end

  def test_is_heavy
    # Per-query caller + backtrace cleaning must not bias the light pass's timing/GC numbers.
    assert Awfy::Rails::Collectors::Sql.heavy?
  end

  # Mirrors Rails::BacktraceCleaner's default: a filter that strips the app root prefix
  # (only when present, like Rails' `line.start_with?(@root) ? line.from(@root.size) :
  # line`), applied before any silencer runs (ActiveSupport::BacktraceCleaner#clean
  # filters first, then silences).
  def root_stripping_cleaner(app_root)
    cleaner = ::ActiveSupport::BacktraceCleaner.new
    cleaner.add_filter { |line| line.start_with?("#{app_root}/") ? line.delete_prefix("#{app_root}/") : line }
    cleaner
  end

  def test_default_frame_finder_uses_the_apps_backtrace_cleaner
    app_root = "/app"
    cleaner = root_stripping_cleaner(app_root)
    # A silencer for non-app lines: after the filter above, only lines outside app_root
    # are still absolute (start with "/").
    cleaner.add_silencer { |line| line.start_with?("/") }
    stack = ["#{app_root}/app/jobs/thing_job.rb:5:in 'perform'", "/some/other/gem/lib/foo.rb:3:in 'bar'"]

    with_stub_rails(cleaner:, root: app_root) do
      assert_equal "app/jobs/thing_job.rb:5:in 'perform'", Awfy::Rails::Collectors::Sql.rails_frame(stack)
    end
  end

  def test_default_frame_finder_skips_the_awfy_gems_own_frames_when_unsilenced
    app_root = "/app"
    cleaner = root_stripping_cleaner(app_root)
    # No silencer here (BACKTRACE env / an app that removes silencers): every frame,
    # including awfy's own subscriber block, survives cleaning unchanged.
    awfy_frame = "#{Awfy::Rails::Collectors::Sql::AWFY_LIB_DIR}/awfy/rails/collectors/sql.rb:60:in 'block in start'"
    app_frame = "#{app_root}/app/jobs/thing_job.rb:5:in 'perform'"

    with_stub_rails(cleaner:, root: app_root) do
      assert_equal "app/jobs/thing_job.rb:5:in 'perform'", Awfy::Rails::Collectors::Sql.rails_frame([awfy_frame, app_frame])
    end
  end

  private

  # A minimal stand-in for the host app's ::Rails, restored/undefined afterward.
  def with_stub_rails(cleaner:, root:)
    fake_rails = Module.new do
      define_singleton_method(:backtrace_cleaner) { cleaner }
      define_singleton_method(:root) { root }
    end
    Object.const_set(:Rails, fake_rails)
    yield
  ensure
    Object.send(:remove_const, :Rails) if defined?(::Rails)
  end
end
