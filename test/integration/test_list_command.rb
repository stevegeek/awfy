# frozen_string_literal: true

require_relative "integration_test_helper"

class ListCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
  end

  def teardown
    teardown_test_environment
  end

  def test_list_command_outputs_correct_format
    output = run_command("suite", "list", options: {list: true})

    # Test that groups are listed
    assert_match(/Test Group/, output)
    assert_match(/Another Group/, output)

    # Test that reports are listed
    assert_match(/\#\+/, output)
    assert_match(/\#\*/, output)
    assert_match(/\#to_s/, output)

    # Test that tests are listed
    assert_match(/Integer/, output)
    assert_match(/Float/, output)
    assert_match(/Array/, output)

    # Test that control/test indicators are present
    assert_match(/Control:/, output)
    assert_match(/Test:/, output)
  end

  def test_list_command_with_specific_group
    output = run_command("suite", "list", "Test Group", options: {list: true})

    # Should include the specified group
    assert_match(/Test Group/, output)

    # Should include reports from that group
    assert_match(/\#\+/, output)
    assert_match(/\#\*/, output)

    # Should NOT include the other group
    refute_match(/Another Group/, output)
    refute_match(/\#to_s/, output)
  end

  def test_list_command_with_table_format
    output = run_command("suite", "list", options: {list: false})

    # Test table format with table_tennis format
    assert_match(/group/i, output) # Headers
    assert_match(/report/i, output)
    assert_match(/test/i, output)
    assert_match(/type/i, output)

    # Test content within table
    assert_match(/Test Group/, output)
    assert_match(/\#\+/, output)
    assert_match(/Integer/, output)
    assert_match(/Float/, output)
    assert_match(/Control/, output)
    assert_match(/Test/, output)
    assert_match(/Another Group/, output)
    assert_match(/\#to_s/, output)
    assert_match(/Array/, output)
  end

  def test_list_command_with_specific_group_and_table_format
    output = run_command("suite", "list", "Another Group", options: {list: false})

    # Should include table formatting (now table_tennis)
    assert_match(/group/i, output)
    assert_match(/report/i, output)

    # Should include only "Another Group" entries
    assert_match(/Another Group/, output)
    assert_match(/\#to_s/, output)
    assert_match(/Integer/, output)
    assert_match(/Float/, output)
    assert_match(/Control/, output)
    assert_match(/Test/, output)

    # Should NOT include "Test Group" entries
    refute_match(/Test Group/, output)
    refute_match(/\#\+/, output)
  end
end
