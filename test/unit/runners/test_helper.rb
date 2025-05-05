# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "ostruct"
require "thor"

# Helper module with common test utilities for runner tests
module RunnerTestHelpers
  # Create a mock Git client for testing runners
  def create_mock_git_client
    git_client = Object.new

    # Define current_branch method
    def git_client.current_branch
      "master"
    end

    # Define lib object with Git command methods
    lib = Object.new
    def lib.stash_save(message)
    end

    def lib.command(cmd, *args)
      case cmd
      when "rev-parse"
        "abcd1234" # Mock commit hash
      when "rev-list"
        "commit1\ncommit2\ncommit3" # Mock commit list
      when "log"
        "Test commit message" # Mock commit message
      else
        "mock output"
      end
    end

    # Define lib method to return our mock lib object
    def git_client.lib
      @lib ||= Object.new.tap do |obj|
        def obj.stash_save(message)
        end

        def obj.command(cmd, *args)
          case cmd
          when "rev-parse"
            "abcd1234" # Mock commit hash
          when "rev-list"
            "commit1\ncommit2\ncommit3" # Mock commit list
          when "log"
            "Test commit message" # Mock commit message
          else
            "mock output"
          end
        end
      end
    end

    # Define checkout method
    def git_client.checkout(ref)
    end

    git_client
  end

  # Create a mock suite with groups for testing
  def create_mock_suite
    OpenStruct.new(
      groups: {
        "test_group" => OpenStruct.new(
          name: "test_group",
          reports: {
            "test_report" => OpenStruct.new(
              name: "test_report",
              tests: ["test1"]
            )
          }
        )
      }
    )
  end

  # Create options for testing with temporary directories
  def create_test_options(test_dir)
    temp_output_dir = File.join(test_dir, "test_bench_output")
    results_dir = File.join(test_dir, "test_bench_results")

    OpenStruct.new(
      verbose: false,
      runtime: "ruby",
      test_time: 1.0,
      test_warm_up: 0.5,
      compare_with_branch: nil,
      setup_file_path: "test/fixtures/benchmarks/setup.rb",
      tests_path: "test/fixtures/benchmarks/tests",
      temp_output_directory: temp_output_dir,
      results_directory: results_dir,
      command: "ips",
      commit_range: nil,
      classic_style: false,
      ascii_only: false,
      no_color: false,
      assert: false,
      humanized_runtime: "ruby",

      # Define required predicate methods
      verbose?: false,
      classic_style?: false,
      ascii_only?: false,
      no_color?: false,
      assert?: false
    )
  end

  # Add stubs to a runner to avoid external dependencies
  def stub_runner_methods(runner)
    # Stub configure_benchmark_run
    runner.define_singleton_method(:configure_benchmark_run) do
      # do nothing - stub
    end

    # Stub run_cleanup_with_retention_policy
    runner.define_singleton_method(:run_cleanup_with_retention_policy) do
      # do nothing - stub
    end

    # Stub say_configuration
    runner.define_singleton_method(:say_configuration) do
      # do nothing - stub
    end

    runner
  end
end
