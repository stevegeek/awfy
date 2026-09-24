# frozen_string_literal: true

require "test_helper"
require "benchmark/ips"
require_relative "../test_helper"

module Awfy
  module Views
    module IPS
      class TestSummaryTable < ViewTestCase
        def create_ips_result(
          test_name: "test1",
          timestamp: Time.now,
          branch: "main",
          commit_hash: "abc12345",
          runtime: Runtimes::MRI,
          baseline: true,
          control: false
        )
          IPSResult.new(
            type: :ips,
            baseline: baseline,
            control: control,
            group_name: "test_group",
            report_name: "test_report",
            test_name: test_name,
            runtime: runtime,
            timestamp: timestamp,
            branch: branch,
            commit_hash: commit_hash,
            commit_message: "Test commit",
            result_data: {
              measured_us: 1000.0,
              iter: 100,
              samples: [100.0, 110.0, 105.0, 95.0, 100.0],
              cycles: 10
            }
          )
        end

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

        def test_headers_returns_expected_keys
          table = SummaryTable.new(
            session: @session,
            group_name: "test_group",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          headers = table.headers

          assert_kind_of Hash, headers
          assert headers.key?(:timestamp)
          assert headers.key?(:branch)
          assert headers.key?(:commit_hash)
          assert headers.key?(:runtime)
          assert headers.key?(:test_name)
          assert headers.key?(:value)
          assert headers.key?(:diff)
        end

        def test_columns_returns_header_keys
          table = SummaryTable.new(
            session: @session,
            group_name: "test_group",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          columns = table.columns
          headers = table.headers

          assert_equal headers.keys, columns
        end

        def test_color_scales_returns_expected_scales
          table = SummaryTable.new(
            session: @session,
            group_name: "test_group",
            report_name: nil,
            test_name: nil,
            rows: []
          )

          scales = table.color_scales

          assert_kind_of Hash, scales
          assert_equal :rg, scales[:value]
          assert_equal :b, scales[:diff]
        end

        def test_build_row_creates_row
          result = create_ips_result

          row = SummaryTable.build_row(
            result,
            is_baseline: true,
            diff_message: "+10%",
            chart: "████",
            control_commit: nil
          )

          assert_instance_of Row, row
        end

        def test_build_row_sets_highlight_for_baseline
          result = create_ips_result

          row = SummaryTable.build_row(
            result,
            is_baseline: true,
            diff_message: "",
            chart: "",
            control_commit: nil
          )

          assert row.highlight?
        end

        def test_build_row_no_highlight_for_non_baseline
          result = create_ips_result(baseline: false)

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "",
            chart: "",
            control_commit: nil
          )

          refute row.highlight?
        end

        def test_build_row_includes_expected_columns
          result = create_ips_result(
            test_name: "my_test",
            branch: "feature",
            commit_hash: "def67890"
          )

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "-5%",
            chart: "██",
            control_commit: nil
          )

          columns = row.columns
          assert_equal "feature", columns[:branch]
          assert_equal "def67890", columns[:commit_hash]
          assert_equal "-5%", columns[:diff]
          assert_equal "██", columns[:chart]
        end

        def test_build_row_control_indicator_for_control_test
          result = create_ips_result(control: true)

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "",
            chart: "",
            control_commit: nil
          )

          assert_equal "✓", row.columns[:control_indicator]
        end

        def test_build_row_control_indicator_for_control_commit
          result = create_ips_result(commit_hash: "abc12345")

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "",
            chart: "",
            control_commit: "abc12345"
          )

          assert_equal "✓", row.columns[:control_indicator]
        end

        def test_build_row_no_control_indicator_normally
          result = create_ips_result(control: false)

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "",
            chart: "",
            control_commit: nil
          )

          assert_equal "", row.columns[:control_indicator]
        end

        def test_build_row_handles_nil_commit_hash
          result = IPSResult.new(
            type: :ips,
            baseline: true,
            control: false,
            group_name: "test_group",
            report_name: "test_report",
            test_name: "test1",
            runtime: "mri",
            timestamp: Time.now,
            branch: nil,
            commit_hash: nil,
            commit_message: nil,
            result_data: {
              measured_us: 1000.0,
              iter: 100,
              samples: [100.0],
              cycles: 10
            }
          )

          row = SummaryTable.build_row(
            result,
            is_baseline: false,
            diff_message: "",
            chart: "",
            control_commit: nil
          )

          assert_equal "?", row.columns[:branch]
          assert_equal "?", row.columns[:commit_hash]
        end
      end
    end
  end
end
