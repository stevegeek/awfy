# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    # Base class for all benchmark commands
    class Base
      CONTROL_MARKER = "[c]"
      TEST_MARKER = "[*]"

      def initialize(runner, shell, git_client: nil, options: nil)
        @runner = runner
        @runner_start_time = runner.start_time
        @shell = shell
        @git_client = git_client
        @options = options
        @result_manager = Services::ResultManager.new(shell, options)
      end

      attr_reader :runner, :options, :git_client, :result_manager

      def say(...) = @shell.say(...)

      def say_error(...) = @shell.say_error(...)

      def verbose? = options.verbose?

      def show_summary? = options.show_summary?

      # Create a formatted test label
      # @param test [Hash] The test data
      # @param runtime [String] The runtime used (e.g., "mri", "yjit")
      # @return [String] The formatted test label
      def generate_test_label(test, runtime)
        "[#{runtime}] #{test[:control] ? CONTROL_MARKER : TEST_MARKER} #{test[:name]}"
      end

      # Run benchmarks with different runtimes
      # @param group [Hash] The benchmark group
      # @param report_name [String, nil] The report name
      # @yield [Hash, String] Yields the report and runtime
      def execute_report(group, report_name, &)
        runtime = options.runtime
        if runtime == "both" || runtime == "mri"
          say "| run with MRI" if verbose?
          execute_group(group, report_name, "mri", true, &)
        end
        if runtime == "both" || runtime == "yjit"
          say "| run with YJIT" if verbose?
          raise "YJIT not supported" unless defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)
          RubyVM::YJIT.enable
          execute_group(group, report_name, "yjit", true, &)
        end
        say if verbose?
      end

      # Execute benchmarks for a group
      # @param group [Hash] The benchmark group
      # @param report_name [String, nil] The report name
      # @param runtime [String] The runtime to use
      # @param include_control [Boolean] Whether to include control tests
      # @yield [Hash, String] Yields the report and runtime
      def execute_group(group, report_name, runtime, include_control = true)
        reports = report_name ? group[:reports].select { |r| r[:name] == report_name } : group[:reports]

        if reports.empty?
          if report_name
            say_error "Report '#{report_name}' not found in group '#{group[:name]}'"
          else
            say_error "No reports found in group '#{group[:name]}'"
          end
          exit(1)
        end

        reports.each do |report|
          # We dont execute the `control` blocks if include_control is false
          run_report = report.dup
          run_report[:tests] = report[:tests].reject { |test| test[:control] && !include_control }

          say if verbose?
          say "> --------------------------" if verbose?
          say "> [#{runtime}] #{group[:name]} / #{report[:name]}", :magenta
          say "> --------------------------" if verbose?
          say if verbose?
          yield run_report, runtime
          say "<< End Report", :magenta if verbose?
        end
      end

      # Execute tests for a report
      # @param report [Hash] The report data
      # @param test_name [String, nil] The test name
      # @param output [Boolean] Whether to output test info
      # @yield [Hash, Integer] Yields the test and iterations
      def execute_tests(report, test_name, output: true, &)
        iterations = options.test_iterations || 1
        sorted_tests = report[:tests].sort { _1[:control] ? -1 : 1 }

        tests = test_name ? sorted_tests.select { |t| t[:name] == test_name } : sorted_tests

        if tests.empty?
          if test_name
            say_error "Test '#{test_name}' not found in report '#{report[:name]}'"
          else
            say_error "No tests found in report '#{report[:name]}'"
          end
          exit(1)
        end

        tests.each do |test|
          if output
            say "# ***" if verbose?
            say "# #{test[:control] ? "Control" : "Test"}: #{test[:name]}", :green
            say "# ***" if verbose?
            say
          end
          test[:block].call # run once to lazy load etc
          yield test, iterations
          if output
            say
          end
        end
      end

      # Save benchmark results
      def save_to(type, group, report, runtime)
        @result_manager.save_results(type, group, report, runtime, @runner_start_time) do
          yield
        end
      end

      # Read results for analysis and summary generation
      def read_reports(type)
        @result_manager.load_results_for_analysis(type, @runner_start_time) do |report_data, results, baseline|
          yield report_data, results, baseline
        end
      end
    end
  end
end
