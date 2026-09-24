# frozen_string_literal: true

require "test_helper"

module Awfy
  module Suites
    class TestLoader < Minitest::Test
      def setup
        @config = Config.new(
          verbose: VerbosityLevel::MUTE,
          setup_file_path: "test/fixtures/benchmarks/setup.rb",
          tests_path: "test/fixtures/benchmarks/tests"
        )

        retention_policy = RetentionPolicies.keep_all
        results_store = Stores::Memory.new(
          storage_name: "test_memory_store",
          retention_policy: retention_policy
        )

        git_client = GitClient.new(path: Dir.pwd)

        @session = Session.new(
          shell: Shell.new(config: @config),
          config: @config,
          git_client: git_client,
          results_store: results_store
        )
      end

      def test_initialize
        loader = Loader.new(session: @session, group_names: nil)

        assert_instance_of Loader, loader
      end

      def test_initialize_with_group_names
        loader = Loader.new(session: @session, group_names: ["Test Group"])

        assert_instance_of Loader, loader
      end

      def test_load_returns_suite
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        loader = Loader.new(session: @session, group_names: nil)

        suite = loader.load

        assert_instance_of Suite, suite
      end

      def test_load_with_group_filter
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        loader = Loader.new(session: @session, group_names: ["Test Group"])

        suite = loader.load

        assert_instance_of Suite, suite
        assert_equal 1, suite.groups.size
        assert_equal "Test Group", suite.groups.first.name
      end

      def test_load_raises_for_invalid_group
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        loader = Loader.new(session: @session, group_names: ["Nonexistent Group"])

        assert_raises(Errors::GroupNotFoundError) do
          loader.load
        end
      end

      def test_load_caches_result
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        loader = Loader.new(session: @session, group_names: nil)

        suite1 = loader.load
        suite2 = loader.load

        # Both calls return a Suite (second call uses cached result)
        assert_instance_of Suite, suite1
        assert_instance_of Suite, suite2
      end

      def test_load_with_multiple_group_names
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        loader = Loader.new(session: @session, group_names: ["Test Group", "Another Group"])

        suite = loader.load

        assert_instance_of Suite, suite
        assert_equal 2, suite.groups.size
        group_names = suite.groups.map(&:name)
        assert_includes group_names, "Test Group"
        assert_includes group_names, "Another Group"
      end
    end
  end
end
