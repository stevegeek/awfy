# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Views
    class TestTable < ViewTestCase
      def create_test_rows
        [
          Row.new(identifier: "row-1", columns: {name: "Test 1", value: 100}, highlight: true),
          Row.new(identifier: "row-2", columns: {name: "Test 2", value: 200}, highlight: false)
        ]
      end

      def test_initialize
        rows = create_test_rows
        table = Table.new(
          session: @session,
          group_name: "test_group",
          report_name: "test_report",
          test_name: "test_method",
          rows: rows
        )

        assert_instance_of Table, table
        assert_equal rows, table.rows
      end

      def test_title_with_all_components
        table = Table.new(
          session: @session,
          group_name: "my_group",
          report_name: "my_report",
          test_name: "my_test",
          rows: []
        )

        assert_equal "Run: my_group/my_report/my_test", table.title
      end

      def test_title_with_group_only
        table = Table.new(
          session: @session,
          group_name: "my_group",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal "Run: my_group", table.title
      end

      def test_title_with_group_and_report
        table = Table.new(
          session: @session,
          group_name: "my_group",
          report_name: "my_report",
          test_name: nil,
          rows: []
        )

        assert_equal "Run: my_group/my_report", table.title
      end

      def test_order_description_asc
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          summary_order: "asc"
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal "Results displayed in ascending order", table.order_description
      end

      def test_order_description_desc
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          summary_order: "desc"
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal "Results displayed in descending order", table.order_description
      end

      def test_order_description_leader
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          summary_order: "leader"
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal "Results displayed as a leaderboard (best to worst)", table.order_description
      end

      def test_theme_dark
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          color: ColorMode::DARK.value
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal :dark, table.theme
      end

      def test_theme_light
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          color: ColorMode::LIGHT.value
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal :light, table.theme
      end

      def test_theme_ansi
        config = Config.new(
          verbose: VerbosityLevel::NONE.value,
          color: ColorMode::ANSI.value
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        table = Table.new(
          session: session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_equal :ansi, table.theme
      end

      def test_headers_returns_nil_by_default
        table = Table.new(
          session: @session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_nil table.headers
      end

      def test_columns_returns_nil_by_default
        table = Table.new(
          session: @session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_nil table.columns
      end

      def test_mark_returns_proc_checking_highlight
        table = Table.new(
          session: @session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        mark_proc = table.mark
        assert_respond_to mark_proc, :call
      end

      def test_color_scales_returns_nil_by_default
        table = Table.new(
          session: @session,
          group_name: "test",
          report_name: nil,
          test_name: nil,
          rows: []
        )

        assert_nil table.color_scales
      end
    end
  end
end
