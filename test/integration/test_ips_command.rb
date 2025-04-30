# frozen_string_literal: true

require "test_helper"
require_relative "integration_test_helper"

class IPSCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
  end

  def teardown
    teardown_test_environment
  end

  def test_ips_command_runs_and_produces_output
    # Run IPS with minimal warmup and test time (handled by helper)
    output = run_command("ips")

    # Test basic output
    assert_match(/Running IPS for:/, output)

    # Test that results include our test groups
    assert_match(/Test Group/, output)
  end

  def test_ips_command_with_summary
    # Run IPS with minimal warmup and test time and summary output
    # The summary setting is default so no need to specify
    output = run_command("ips")

    # Test that results include our test groups
    assert_match(/Test Group/, output)

    # Test that report names are included
    assert_match(/\#+/, output)

    # Test that different runtimes are included
    assert_match(/\[mri/, output)
    assert_match(/\[yjit/, output)
  end

  def test_ips_command_stores_results
    # Run IPS command
    run_command("ips")

    # Get the result store instance
    result_store = Awfy::ResultStoreFactory.instance(Awfy::Options.new(storage_backend: :memory))

    # Check that results were stored in the memory store
    refute_empty result_store.stored_results, "No results were stored in the ResultStore"

    # Verify each stored result has the expected structure with samples
    result_store.stored_results.each do |_, result|
      # Check result type is :ips
      assert_equal :ips, result[:type]

      # Verify data structure
      refute_nil result[:data], "Result data should not be nil"
      assert_kind_of Array, result[:data], "Result data should be an array"

      # Check that each entry has the expected data structure
      result[:data].each do |entry|
        # Check required keys exist
        assert entry.key?(:label), "Entry should have a label"
        assert entry.key?(:measured_us), "Entry should have measured_us"
        assert entry.key?(:iter), "Entry should have iter (iterations)"
        assert entry.key?(:stats), "Entry should have stats"
        assert entry.key?(:control), "Entry should have control flag"
        assert entry.key?(:cycles), "Entry should have cycles"

        # Check data types
        assert_kind_of String, entry[:label], "Label should be a string"
        assert_kind_of Float, entry[:measured_us], "measured_us should be a float"
        assert_kind_of Integer, entry[:iter], "iterations should be an integer"
        assert_kind_of TrueClass, entry[:control], "control should be a boolean" if entry[:control]
        assert_kind_of FalseClass, entry[:control], "control should be a boolean" if !entry[:control]
        assert_kind_of Integer, entry[:cycles], "cycles should be an integer"

        # Verify stats contains samples
        stats = entry[:stats]
        assert_respond_to stats, :samples, "Stats should have samples"
        refute_empty stats.samples, "Samples array should not be empty"

        # Verify samples are numeric values
        stats.samples.each do |sample|
          assert_kind_of Numeric, sample, "Sample should be a numeric value"
        end
      end
    end
  end
end
