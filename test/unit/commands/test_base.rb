# frozen_string_literal: true

require "test_helper"

# Testable subclass that exposes private methods - defined outside the test class
class TestableCommand < Awfy::Commands::Base
  def run
    # No-op for testing
  end

  def test_load_suite!
    load_suite!
  end
end

class TestCommandsBase < Minitest::Test
  def setup
    @config = Awfy::Config.new(
      verbose: false,
      runtime: "mri",
      test_time: 0.1,
      test_warm_up: 0.05,
      color: Awfy::ColorMode::OFF,
      summary: false,
      storage_backend: "memory",
      setup_file_path: "test/fixtures/benchmarks/setup.rb",
      tests_path: "test/fixtures/benchmarks/tests"
    )
    @session = create_session(@config)
  end

  def create_session(config)
    retention_policy = Awfy::RetentionPolicies.keep_all
    results_store = Awfy::Stores::Memory.new(
      storage_name: "test_memory_store",
      retention_policy: retention_policy
    )

    git_client = Awfy::GitClient.new(path: Dir.pwd)

    Awfy::Session.new(
      shell: Awfy::Shell.new(config: config),
      config: config,
      git_client: git_client,
      results_store: results_store
    )
  end

  def test_initialize_with_all_parameters
    command = TestableCommand.new(
      session: @session,
      group_names: ["group1"],
      report_name: "report1",
      test_name: "test1"
    )

    assert_instance_of TestableCommand, command
  end

  def test_initialize_with_nil_parameters
    command = TestableCommand.new(
      session: @session,
      group_names: nil,
      report_name: nil,
      test_name: nil
    )

    assert_instance_of TestableCommand, command
  end

  def test_initialize_with_multiple_group_names
    command = TestableCommand.new(
      session: @session,
      group_names: ["group1", "group2", "group3"],
      report_name: nil,
      test_name: nil
    )

    assert_instance_of TestableCommand, command
  end

  def test_load_suite_loads_from_fixtures
    command = TestableCommand.new(
      session: @session,
      group_names: nil,
      report_name: nil,
      test_name: nil
    )

    # Note: This test depends on fixtures existing
    # The actual behavior requires setup.rb and test files to exist
    # Skip if fixtures don't exist
    setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
    unless File.exist?(setup_file)
      skip "Fixture file not found: #{setup_file}"
    end

    suite = command.test_load_suite!
    assert_instance_of Awfy::Suite, suite
  end

  def test_load_suite_with_group_filter
    command = TestableCommand.new(
      session: @session,
      group_names: ["test"],
      report_name: nil,
      test_name: nil
    )

    setup_file = File.expand_path(@config.setup_file_path, Dir.pwd)
    unless File.exist?(setup_file)
      skip "Fixture file not found: #{setup_file}"
    end

    # This might raise GroupNotFoundError if "test" group doesn't exist
    begin
      suite = command.test_load_suite!
      # If group exists, verify it was filtered
      group_names = suite.groups.map(&:name)
      assert_equal ["test"], group_names
    rescue Awfy::Errors::GroupNotFoundError
      # Expected if "test" group doesn't exist in fixtures
      pass
    end
  end
end
