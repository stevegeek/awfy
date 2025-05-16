# frozen_string_literal: true

require_relative "views/test_helper"
require "awfy/views/table"

# Test class for TableFormatter functionality
class TestTable < ViewTestCase
  # TestTableClass is a dummy class for testing Table functionality
  class TestTableClass < Awfy::Views::Table
    def initialize(results:, session:, title: nil, order_description: nil)
      super
    end

    def render
      @shell.say("Table rendered")
    end
  end

  def setup
    super

    # Sample results for testing
    @results = [
      mock_result(result_data: {ips: 100.0}, report_name: "Report A", test_name: "Test 1"),
      mock_result(result_data: {ips: 200.0}, report_name: "Report A", test_name: "Test 2")
    ]

    # Instantiate TestTableClass with the session
    @table_view = TestTableClass.new(
      results: @results,
      title: "Test Table Title",
      order_description: "Sorted by IPS",
      session: @session
    )
  end

  def test_title
    assert_equal "Test Table Title", @table_view.title
    @table_view.render
    assert_match(/Test Table Title/, @shell.messages.map { |m| m[:message] }.join)
  end

  def test_order_description
    assert_equal "Sorted by IPS", @table_view.order_description
    @table_view.render
    assert_match(/Sorted by IPS/, @shell.messages.map { |m| m[:message] }.join)
  end

  def test_table_rendering_calls_say
    @table_view.render
    assert_includes @shell.messages.map { |m| m[:message] }, "Table rendered"
  end
end
