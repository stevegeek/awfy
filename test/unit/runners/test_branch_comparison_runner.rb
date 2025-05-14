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
  #
  # def test_run_calls_branches_in_order
  #   # Test that run calls branches in the correct order
  #   main_branch = "main"
  #   comparison_branch = "feature"
  #
  #   # Track the order of branch checkouts
  #
  #   # Add a mock safe_checkout method that tracks branch checkouts
  #   def @runner.safe_checkout(branch)
  #     @checkout_order ||= []
  #     @checkout_order << branch
  #     yield if block_given?
  #   end
  #
  #   # Run the comparison
  #   @runner.run(main_branch, comparison_branch)
  #
  #   # Verify branches were checked out in the correct order
  #   assert_equal [main_branch, comparison_branch], @runner.instance_variable_get(:@checkout_order)
  # end
  #
  # def test_run_with_specific_group
  #   # Test that run with a specific group only runs that group
  #   main_branch = "main"
  #   comparison_branch = "feature"
  #   group_name = "test_group"
  #
  #   # Track which groups were run
  #
  #   # Mock the run_in_fresh_process method to track groups
  #   def @runner.run_in_fresh_process(cmd_type, group, report_name, test_name)
  #     @run_groups ||= []
  #     @run_groups << group
  #   end
  #
  #   # Add a mock safe_checkout method
  #   def @runner.safe_checkout(branch)
  #     yield if block_given?
  #   end
  #
  #   # Run the comparison with a specific group
  #   @runner.run(main_branch, comparison_branch, group_name)
  #
  #   # Verify the specific group was run
  #   assert_equal [group_name, group_name], @runner.instance_variable_get(:@run_groups)
  # end
  #
  # def test_combine_results_merges_branch_data
  #   # Test that combine_results correctly merges data from both branches
  #   main_results = {
  #     "group1" => [{"name" => "test1", "branch" => "main", "value" => 100}]
  #   }
  #   comparison_results = {
  #     "group1" => [{"name" => "test1", "branch" => "feature", "value" => 110}]
  #   }
  #
  #   combined = @runner.send(:combine_results, main_results, comparison_results)
  #
  #   # Verify the results were combined correctly
  #   assert_equal 2, combined["group1"].size
  #   assert_includes combined["group1"].map { |r| r["branch"] }, "main"
  #   assert_includes combined["group1"].map { |r| r["branch"] }, "feature"
  # end
end
