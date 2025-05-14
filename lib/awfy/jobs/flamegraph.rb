# frozen_string_literal: true

require "vernier"

module Awfy
  module Jobs
    class Flamegraph < Base
      def call
        if verbose?(VerbosityLevel::BASIC)
          say "> Flamegraph profiling for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          total_tests = report.tests.size

          if verbose?(VerbosityLevel::BASIC)
            say "> Running #{total_tests} flamegraph profiles", :cyan
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
            filename = "report-#{group.name}-#{report.name}-#{test.name}".gsub(/[^A-Za-z0-9_\-]/, "_")

            if verbose?(VerbosityLevel::DEBUG)
              say "# ***"
              say "# #{test.name}", :green
              say "# ***"
              say
            end

            generate_flamegraph(filename, open: verbose?(VerbosityLevel::DEBUG)) do
              iterations.times { test.block.call }
            end

            progress_bar.increment
          end

          progress_bar.finish
        end
      end

      private

      def generate_flamegraph(filename = nil, open: true, ignore_gc: false, interval: 1000, &)
        result = Vernier.profile(out: filename, gc: !ignore_gc, interval: interval, &)
        `bundle exec profile-viewer #{filename}` if open
        result
      end
    end
  end
end
