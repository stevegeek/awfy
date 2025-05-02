# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/base_view"

class TestBaseView < ViewTestCase
  def setup
    super
    @view = Awfy::Views::BaseView.new(@shell, @options)
  end

  def test_initialization
    assert_instance_of Awfy::Views::BaseView, @view
  end

  def test_say
    @view.say("Test message")
    assert_equal 1, @shell.messages.size
    assert_equal "Test message", @shell.messages.first[:message]
    assert_nil @shell.messages.first[:color]

    @view.say("Colored message", :red)
    assert_equal 2, @shell.messages.size
    assert_equal "Colored message", @shell.messages.last[:message]
    assert_equal :red, @shell.messages.last[:color]
  end

  def test_say_error
    @view.say_error("Error message")
    assert_equal 1, @shell.errors.size
    assert_equal "Error message", @shell.errors.first
  end

  def test_verbose
    @options.verbose = false
    assert_equal false, @view.verbose?

    @options.verbose = true
    assert_equal true, @view.verbose?
  end

  def test_show_summary
    @options.show_summary = false
    assert_equal false, @view.show_summary?

    @options.show_summary = true
    assert_equal true, @view.show_summary?
  end

  def test_format_table
    title = "Test Table"
    headings = ["Col1", "Col2", "Col3"]
    rows = [
      ["A", 1, 2.5],
      ["B", 2, 3.5],
      ["C", 3, 4.5]
    ]

    table = @view.format_table(title, headings, rows)
    assert_instance_of Terminal::Table, table

    # Convert the table to string and check some basics
    table_string = table.to_s
    assert_includes table_string, title
    headings.each do |heading|
      assert_includes table_string, heading
    end

    # Check content
    assert_includes table_string, "A"
    assert_includes table_string, "B"
    assert_includes table_string, "C"
  end

  def test_humanize_scale
    # Test zero
    assert_equal "0", @view.humanize_scale(0)

    # Test small numbers
    assert_equal "500", @view.humanize_scale(500)

    # Test thousands
    assert_equal "1.5k", @view.humanize_scale(1500)

    # Test millions
    assert_equal "2.5M", @view.humanize_scale(2_500_000)

    # Test billions
    assert_equal "3.5B", @view.humanize_scale(3_500_000_000)
  end

  def test_format_change
    # Test no change
    assert_equal "No change", @view.format_change(1.0)

    # Test increase
    assert_equal "+50.0%", @view.format_change(1.5)

    # Test decrease
    assert_equal "-50.0%", @view.format_change(0.5)
  end

  def test_format_comparison
    # Test baseline
    assert_equal "baseline", @view.format_comparison(1.0)

    # Test higher is better (default)
    assert_equal "2.0x faster", @view.format_comparison(2.0)
    assert_equal "2.0x slower", @view.format_comparison(0.5)

    # Test lower is better
    assert_equal "2.0x better", @view.format_comparison(0.5, false)
    assert_equal "2.0x worse", @view.format_comparison(2.0, false)
  end
end
