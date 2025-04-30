# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class MemoryCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment

    # Override the save_memory_profile_report_to_file method to prevent actual file writing
    Awfy::Commands::Memory.class_eval do
      alias_method :original_save_memory_profile_report_to_file, :save_memory_profile_report_to_file

      def save_memory_profile_report_to_file(file_name, results)
        # Skip file writing in tests to avoid nil conversion errors
        # Just return a dummy result that can be converted to JSON
        []
      end
    end
  end

  def teardown
    # Restore the original method
    Awfy::Commands::Memory.class_eval do
      alias_method :save_memory_profile_report_to_file, :original_save_memory_profile_report_to_file
      remove_method :original_save_memory_profile_report_to_file
    end

    teardown_test_environment
  end

  def test_memory_command_runs_and_produces_output
    # Run memory profiling
    output = run_command("memory")

    # Test basic output
    assert_match(/Memory profiling for:/, output)

    # Test that results include our test groups
    assert_match(/Test Group/, output)
  end

  def test_memory_command_with_summary
    # Run memory command with summary output (default)
    output = run_command("memory")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Test that report names are included
    assert_match(/\#+/, output)

    # Test that different runtimes are included
    assert_match(/\[mri/, output)
    assert_match(/\[yjit/, output)
  end
end
