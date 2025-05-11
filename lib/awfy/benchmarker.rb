# frozen_string_literal: true

module Awfy
  # Responsible for executing benchmark groups, reports, and tests in the current process.
  class Benchmarker < Literal::Object
    include HasSession

    def run(group, report_name, &block)
      runtime = config.runtime
      if runtime == "both" || runtime == "mri"
        say "| run with MRI" if verbose?
        run_group(group, report_name, "mri", true, &block)
      end
      if runtime == "both" || runtime == "yjit"
        say "| run with YJIT" if verbose?
        raise "YJIT not supported" unless defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)
        RubyVM::YJIT.enable
        run_group(group, report_name, "yjit", true, &block)
      end
      say if verbose?
    end

    def run_group(group, report_name, runtime, include_control = true, &block)
      reports = report_name ? group.reports.select { |r| r.name == report_name } : group.reports

      if reports.empty?
        if report_name
          say_error "Report '#{report_name}' not found in group '#{group.name}'"
        else
          say_error "No reports found in group '#{group.name}'"
        end
        exit(1)
      end

      reports.each do |report|
        run_report = include_control ? report : report.without_control_tests

        say if verbose?
        say "> --------------------------" if verbose?
        say "> [#{runtime}] #{group.name} / #{report.name}", :magenta
        say "> --------------------------" if verbose?
        say if verbose?
        yield run_report, runtime
        say "<< End Report", :magenta if verbose?
      end
    end

    def run_tests(report, test_name, output: true, &block)
      iterations = config.test_iterations || 1
      tests = report.tests_sorted_by_type(test_name:)

      if tests.empty?
        if test_name
          say_error "Test '#{test_name}' not found in report '#{report.name}'"
        else
          say_error "No tests found in report '#{report.name}'"
        end
        exit(1)
      end

      tests.each do |test|
        if output
          say "# ***" if verbose?
          say "# #{test.control ? "Control" : "Test"}: #{test.name}", :green
          say "# ***" if verbose?
          say
        end
        test.block.call # run once to lazy load etc
        yield test, iterations
        if output
          say
        end
      end
    end
  end
end
