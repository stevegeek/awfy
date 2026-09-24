# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestResultsManager < Minitest::Test
    def setup
      @config = Config.new(
        verbose: false,
        runtime: "mri",
        test_time: 0.1,
        test_warm_up: 0.05,
        color: ColorMode::OFF,
        summary: false,
        storage_backend: "memory"
      )
      @session = create_session(@config)
    end

    def create_session(config)
      retention_policy = RetentionPolicies.keep_all
      results_store = Stores::Memory.new(
        storage_name: "test_memory_store",
        retention_policy: retention_policy
      )

      git_client = GitClient.new(path: Dir.pwd)

      Session.new(
        shell: Shell.new(config: config),
        config: config,
        git_client: git_client,
        results_store: results_store
      )
    end

    def test_initialize
      results_manager = ResultsManager.new(session: @session)
      assert_instance_of ResultsManager, results_manager
    end

    def test_save_new_result_returns_result_id
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0, 11.0, 12.0],
        cycles: 10
      }

      result_id = results_manager.save_new_result(
        :ips,
        group,
        report,
        "mri",
        test,
        result_data,
        commit_hash: "abc123",
        commit_message: "Test commit",
        branch: "main"
      )

      assert_kind_of String, result_id
      assert_match(/[a-zA-Z0-9_-]+/, result_id)
    end

    def test_save_new_result_stores_in_store
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0, 11.0, 12.0],
        cycles: 10
      }

      results_manager.save_new_result(
        :ips,
        group,
        report,
        "mri",
        test,
        result_data
      )

      # Verify by using each_report to check results were stored
      yielded_count = 0
      results_manager.each_report(:ips) do |results, _|
        yielded_count += 1
        assert_equal 1, results.size
      end
      assert_equal 1, yielded_count
    end

    def test_save_new_result_with_baseline_test
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "baseline", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(:ips, group, report, "mri", test, result_data)

      # Verify via each_report
      results_manager.each_report(:ips) do |results, baseline|
        assert baseline.baseline?
      end
    end

    def test_save_new_result_with_control_test
      results_manager = ResultsManager.new(session: @session)

      # Need both a baseline and control test - baseline is required for each_report
      baseline = Suites::BaselineTest.new(name: "baseline", block: proc {})
      control = Suites::ControlTest.new(name: "control", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [baseline, control])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(:ips, group, report, "mri", baseline, result_data)
      results_manager.save_new_result(:ips, group, report, "mri", control, result_data)

      # Verify via each_report
      control_found = false
      results_manager.each_report(:ips) do |results, _|
        control_found = results.any?(&:control?)
      end
      assert control_found
    end

    def test_each_report_yields_grouped_results
      results_manager = ResultsManager.new(session: @session)

      # Save a baseline test result first
      baseline = Suites::BaselineTest.new(name: "baseline", block: proc {})
      regular = Suites::Test.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [baseline, regular])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(:ips, group, report, "mri", baseline, result_data)
      results_manager.save_new_result(:ips, group, report, "mri", regular, result_data)

      yielded_count = 0
      yielded_baseline = nil

      results_manager.each_report(:ips) do |results, bl|
        yielded_count += 1
        yielded_baseline = bl
      end

      assert_equal 1, yielded_count
      refute_nil yielded_baseline
      assert yielded_baseline.baseline?
    end

    def test_each_report_groups_by_report_name
      results_manager = ResultsManager.new(session: @session)

      baseline1 = Suites::BaselineTest.new(name: "baseline", block: proc {})
      baseline2 = Suites::BaselineTest.new(name: "baseline", block: proc {})
      report1 = Suites::Report.new(name: "report1", tests: [baseline1])
      report2 = Suites::Report.new(name: "report2", tests: [baseline2])
      group = Suites::Group.new(name: "test_group", reports: [report1, report2])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(:ips, group, report1, "mri", baseline1, result_data)
      results_manager.save_new_result(:ips, group, report2, "mri", baseline2, result_data)

      yielded_count = 0

      results_manager.each_report(:ips) do |results, baseline|
        yielded_count += 1
      end

      # Should yield twice - once for each report
      assert_equal 2, yielded_count
    end

    def test_save_memory_result
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        allocated_memsize: 1024,
        allocated_objects: 10,
        retained_memsize: 512,
        retained_objects: 5,
        retained_strings: 2,
        allocated_strings: 4
      }

      result_id = results_manager.save_new_result(:memory, group, report, "mri", test, result_data)

      assert_kind_of String, result_id

      # Verify via each_report
      yielded_count = 0
      results_manager.each_report(:memory) do |results, _|
        yielded_count += 1
        assert_equal 1, results.size
      end
      assert_equal 1, yielded_count
    end

    def test_result_includes_ruby_version
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(:ips, group, report, "mri", test, result_data)

      results_manager.each_report(:ips) do |results, _|
        assert_equal RUBY_VERSION, results.first.ruby_version
      end
    end

    def test_result_includes_git_info
      results_manager = ResultsManager.new(session: @session)

      test = Suites::BaselineTest.new(name: "test1", block: proc {})
      report = Suites::Report.new(name: "test_report", tests: [test])
      group = Suites::Group.new(name: "test_group", reports: [report])

      result_data = {
        measured_us: 1000.0,
        iter: 100,
        samples: [10.0],
        cycles: 10
      }

      results_manager.save_new_result(
        :ips,
        group,
        report,
        "mri",
        test,
        result_data,
        commit_hash: "abc123def",
        commit_message: "Test commit message",
        branch: "feature-branch"
      )

      results_manager.each_report(:ips) do |results, _|
        result = results.first
        assert_equal "abc123def", result.commit_hash
        assert_equal "Test commit message", result.commit_message
        assert_equal "feature-branch", result.branch
      end
    end
  end
end
