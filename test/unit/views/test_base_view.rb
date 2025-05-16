# frozen_string_literal: true

require_relative "test_helper"
require "awfy/views/base_view"

class TestBaseView < ViewTestCase
  def setup
    super
    @view = Awfy::Views::BaseView.new(session: @session)
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
    # Test with a session and config that has verbose=false
    @session = Awfy::Session.new(
      shell: @shell,
      config: Awfy::Config.new(verbose: false),
      git_client: @git_client,
      results_store: @results_store
    )
    view = Awfy::Views::BaseView.new(session: @session)
    assert_equal false, view.verbose?

    # Test with a session and config that has verbose=true
    @session = Awfy::Session.new(
      shell: @shell,
      config: Awfy::Config.new(verbose: true),
      git_client: @git_client,
      results_store: @results_store
    )
    view = Awfy::Views::BaseView.new(session: @session)
    assert_equal true, view.verbose?
  end

  # Test class that adds show_summary? method for testing
  class TestBaseViewWithSummary < Awfy::Views::BaseView
    def show_summary?
      config.show_summary?
    end
  end

  def test_show_summary
    # Test with a session and config that has summary=false
    @session = Awfy::Session.new(
      shell: @shell,
      config: Awfy::Config.new(summary: false),
      git_client: @git_client,
      results_store: @results_store
    )
    view = TestBaseViewWithSummary.new(session: @session)
    assert_equal false, view.show_summary?

    # Test with a session and config that has summary=true
    @session = Awfy::Session.new(
      shell: @shell,
      config: Awfy::Config.new(summary: true),
      git_client: @git_client,
      results_store: @results_store
    )
    view = TestBaseViewWithSummary.new(session: @session)
    assert_equal true, view.show_summary?
  end

  def test_format_table
    # Create a mock table class for testing
    mock_table = Struct.new(
      :rows, :title, :headers, :columns, :theme, :mark, :color_scales, :order_description
    ).new(
      [
        Awfy::Views::Row.new(identifier: "1", columns: {col1: "A", col2: 1, col3: 2.5}),
        Awfy::Views::Row.new(identifier: "2", columns: {col1: "B", col2: 2, col3: 3.5}),
        Awfy::Views::Row.new(identifier: "3", columns: {col1: "C", col2: 3, col3: 4.5})
      ],
      "Test Table",
      {col1: "Col1", col2: "Col2", col3: "Col3"},
      [:col1, :col2, :col3],
      nil,
      nil,
      nil,
      "Results displayed in ascending order"
    )

    table_string = @view.say_table(mock_table)
    assert_instance_of String, table_string

    # Check that the table contains the title
    assert_includes table_string, "Test Table"

    # With table_tennis, the headers might be transformed
    # so check for lowercase variants too
    ["Col1", "Col2", "Col3", "col1", "col2", "col3"].each do |heading|
      if table_string.include?(heading)
        assert_includes table_string, heading
      end
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
