# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

# Test implementation of Base runner
module Awfy
  module Runners
    class TestRunner < Base
      def run(group = nil, &block)
        start!
        if group
          run_group(group, &block)
        else
          run_groups(&block)
        end
      end
    end
  end
end

class TestBranchComparisonRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    # Create test directory first
    @test_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_output"))
    FileUtils.mkdir_p(File.join(@test_dir, "test_bench_results"))

    # Use Thor::Shell::Basic as the shell
    @shell = Thor::Shell::Basic.new

    # Setup options
    @options = create_test_options(@test_dir)

    # Create a suite with mock groups
    @suite = create_mock_suite

    # Create a session
    @session = create_test_session(@options)

    # Create runner instance
    @runner = Awfy::Runners::Sequential::BranchComparisonRunner.new(
      session: @session,
      suite: @suite
    )

    # Add method stubs
    stub_runner_methods(@runner)
  end

  def teardown
    # Clean up test directory
    if defined?(@test_dir) && @test_dir && Dir.exist?(@test_dir)
      FileUtils.remove_entry(@test_dir)
    end
  end

  def test_initialization
    assert_instance_of Awfy::Runners::Sequential::BranchComparisonRunner, @runner
    # Just make sure we can initialize the runner
    assert @runner
  end

  def test_run_calls_branches_in_order
    # Create test result files for each branch
    # This data needs to match what would be added by the load_results method
    main_result = {
      "test_group" => [
        {"name" => "test1", "runtime" => "ruby", "ips" => 100.0, "branch" => "main"}
      ]
    }

    comparison_result = {
      "test_group" => [
        {"name" => "test1", "runtime" => "ruby", "ips" => 150.0, "branch" => "feature"}
      ]
    }

    # We need to mock the branch checkout and result loading
    @runner.method(:run_on_branch)

    @runner.define_singleton_method(:run_on_branch) do |branch, group|
      # Record which branch is being run
      (@branches_run ||= []) << branch

      # Return the appropriate test results
      if branch == "main"
        main_result
      else
        comparison_result
      end
    end

    # Run the test
    results = @runner.run("main", "feature")

    # Check that run_on_branch was called for both branches in the correct order
    branches_run = @runner.instance_variable_get(:@branches_run)
    assert_equal ["main", "feature"], branches_run

    # We need to verify that the results have all the expected data
    # BranchComparisonRunner combines the results from both branches
    assert_equal ["test_group"], results.keys

    # Check that we got both branch results
    test_results = results["test_group"]
    assert_equal 2, test_results.length

    # Find each branch result
    main_result = test_results.find { |r| r["branch"] == "main" }
    feature_result = test_results.find { |r| r["branch"] == "feature" }

    # Verify both branch results are present
    assert main_result, "Result from main branch is missing"
    assert feature_result, "Result from feature branch is missing"

    # Verify the IPS values
    assert_equal 100.0, main_result["ips"]
    assert_equal 150.0, feature_result["ips"]
  end

  def test_run_with_specific_group
    # Create test result files
    main_result = {
      "specific_group" => [
        {"name" => "test1", "runtime" => "ruby", "ips" => 100.0}
      ]
    }

    comparison_result = {
      "specific_group" => [
        {"name" => "test1", "runtime" => "ruby", "ips" => 150.0}
      ]
    }

    # Stub the run_on_branch method to check if the group is passed
    group_args = []
    @runner.define_singleton_method(:run_on_branch) do |branch, group|
      group_args << group

      # Return test results
      (branch == "main") ? main_result : comparison_result
    end

    # Run the test with a specific group
    @runner.run("main", "feature", "specific_group")

    # Check that the group was passed to run_on_branch for all branches
    assert_equal ["specific_group", "specific_group"], group_args
  end

  def test_combine_results_merges_branch_data
    # Test the combine_results method directly
    main_results = {
      "group1" => [
        {"name" => "test1", "branch" => "main", "ips" => 100.0}
      ],
      "group2" => [
        {"name" => "test2", "branch" => "main", "ips" => 200.0}
      ]
    }

    comparison_results = {
      "group1" => [
        {"name" => "test1", "branch" => "feature", "ips" => 150.0}
      ],
      "group3" => [
        {"name" => "test3", "branch" => "feature", "ips" => 300.0}
      ]
    }

    # Call the private method using send
    combined = @runner.send(:combine_results, main_results, comparison_results)

    # Check that all groups are present
    assert_equal ["group1", "group2", "group3"].sort, combined.keys.sort

    # Check that group1 has both branch results
    assert_equal 2, combined["group1"].length
    main_test1 = combined["group1"].find { |r| r["branch"] == "main" }
    feature_test1 = combined["group1"].find { |r| r["branch"] == "feature" }

    assert_equal 100.0, main_test1["ips"]
    assert_equal 150.0, feature_test1["ips"]

    # Check that other groups have their respective results
    assert_equal 1, combined["group2"].length
    assert_equal 1, combined["group3"].length
    assert_equal "main", combined["group2"][0]["branch"]
    assert_equal "feature", combined["group3"][0]["branch"]
  end
end
