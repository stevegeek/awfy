# frozen_string_literal: true

require 'test_helper'
require_relative 'integration_test_helper'

class ListCommandTest < Minitest::Test
  include IntegrationTestHelper

  def setup
    setup_test_environment
  end

  def teardown
    teardown_test_environment
  end

  def test_list_command_outputs_correct_format
    output = run_command('list')

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
    output = run_command('list', 'Test Group')

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
    output = run_command('list', options: {table_format: true})

    # Test table format
    assert_match(/\+-+\+/, output) # Table borders
    assert_match(/\| Group\s+\| Report\s+\| Test\s+\| Type\s+\|/, output) # Headers

    # Test content within table
    assert_match(/\| Test Group\s+\| \#\+\s+\| Integer\s+\| Control\s+\|/, output)
    assert_match(/\| Test Group\s+\| \#\+\s+\| Float\s+\| Test\s+\|/, output)
    assert_match(/\| Another Group\s+\| \#to_s\s+\| Array\s+\| Test\s+\|/, output)
  end

  def test_list_command_with_specific_group_and_table_format
    output = run_command('list', 'Another Group', options: {table_format: true})

    # Should include table format
    assert_match(/\+-+\+/, output) # Table borders

    # Should include only "Another Group" entries
    assert_match(/\| Another Group\s+\| \#to_s\s+\| Integer\s+\| Control\s+\|/, output)
    assert_match(/\| Another Group\s+\| \#to_s\s+\| Float\s+\| Test\s+\|/, output)

    # Should NOT include "Test Group" entries
    refute_match(/\| Test Group\s+\|/, output)
    refute_match(/\| \#\+\s+\|/, output)
  end
end
