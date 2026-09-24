# frozen_string_literal: true

require "test_helper"

module Awfy
  module Commands
    class TestMemory < Minitest::Test
      def setup
        @config = Awfy::Config.new(
          verbose: VerbosityLevel::MUTE,
          runtime: "mri",
          test_time: 0.01,
          test_warm_up: 0.005,
          color: ColorMode::OFF,
          summary: false,
          storage_backend: "memory",
          setup_file_path: "test/fixtures/benchmarks/setup.rb",
          tests_path: "test/fixtures/benchmarks/tests"
        )
        @session = create_session(@config)
      end

      def create_session(config)
        retention_policy = RetentionPolicies.keep_all
        results_store = Stores::Memory.new(
          storage_name: "test_memory_store",
          retention_policy: retention_policy
        )

        git_client = GitClient.new(path: Dir.pwd)

        Session.new(
          shell: Shell.new(config: config),
          config: config,
          git_client: git_client,
          results_store: results_store
        )
      end

      def test_initialize
        command = Memory.new(
          session: @session,
          group_names: nil,
          report_name: nil,
          test_name: nil
        )

        assert_instance_of Memory, command
      end

      def test_inherits_from_base
        command = Memory.new(
          session: @session,
          group_names: nil,
          report_name: nil,
          test_name: nil
        )

        assert_kind_of Base, command
      end

      def test_run_completes_without_error
        setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
        skip "Fixture file not found: #{setup_file}" unless File.exist?(setup_file)

        command = Memory.new(
          session: @session,
          group_names: ["Test Group"],
          report_name: "#+",
          test_name: nil
        )

        # Run should complete without raising
        command.run
        assert true
      end
    end
  end
end
