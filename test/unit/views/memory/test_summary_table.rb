# frozen_string_literal: true

require "test_helper"
require_relative "../test_helper"

module Awfy
  module Views
    module Memory
      class TestSummaryTable < ViewTestCase
        def test_initialize
          table = SummaryTable.new(
            session: @session,
            group_name: "test_group",
            report_name: "test_report",
            test_name: nil,
            rows: []
          )

          assert_instance_of SummaryTable, table
        end

        def test_inherits_from_table
          table = SummaryTable.new(
            session: @session,
            group_name: "test_group",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          assert_kind_of Table, table
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

          table = SummaryTable.new(
            session: session,
            group_name: "test",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          assert_equal "Results displayed in ascending order (lowest memory first)", table.order_description
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

          table = SummaryTable.new(
            session: session,
            group_name: "test",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          assert_equal "Results displayed in descending order (highest memory first)", table.order_description
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

          table = SummaryTable.new(
            session: session,
            group_name: "test",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          assert_equal "Results displayed as a leaderboard (best to worst)", table.order_description
        end

        def test_order_description_default
          config = Config.new(
            verbose: VerbosityLevel::NONE.value
          )
          shell = TestShell.new(config: config)
          session = Session.new(
            shell: shell,
            config: config,
            git_client: @git_client,
            results_store: @results_store
          )

          table = SummaryTable.new(
            session: session,
            group_name: "test",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          # Default is "leader"
          assert_equal "Results displayed as a leaderboard (best to worst)", table.order_description
        end
      end
    end
  end
end
