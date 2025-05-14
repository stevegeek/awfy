# frozen_string_literal: true

require "stackprof"

module Awfy
  module Jobs
    class Profiling < Base
      def call
        if verbose?(VerbosityLevel::BASIC)
          say "> CPU profiling for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          total_tests = report.tests.size

          if verbose?(VerbosityLevel::BASIC)
            say "> Running #{total_tests} CPU profiles", :cyan
          end

          progress_bar = Awfy::Views::ProgressBar.new(
            shell: session.shell,
            total_benchmarks: total_tests,
            ascii_only: config.ascii_only?
          )

          if verbose?(VerbosityLevel::DETAILED)
            say "#{group.name}/#{report.name} [#{runtime}] #{total_tests} tests", :cyan
            say
          end

          benchmarker.run_tests(report, test_name, output: false) do |test, iterations|
            if verbose?(VerbosityLevel::DEBUG)
              say "# ***"
              say "# #{test.name}", :green
              say "# ***"
              say
            end

            data = StackProf.run(mode: :cpu, interval: 100) do
              iterations.times { test.block.call }
            end

            # For now we only support text output
            StackProf::Report.new(data).print_text

            progress_bar.increment
          end

          progress_bar.finish
        end
      end
    end
  end
end
