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
end
