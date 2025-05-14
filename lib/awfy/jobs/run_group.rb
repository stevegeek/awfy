# frozen_string_literal: true

module Awfy
  module Jobs
    # Just simply runs the code of the tests, useful for debugging
    class RunGroup < Base
      def call
        if verbose?(VerbosityLevel::BASIC)
          say "> Running Group:"
          say "> '#{group.name}'", :cyan
          say
        end

        benchmarker.run(group, report_name) do |report, runtime|
          # After defining all benchmark items, set up the progress bar
          benchmark_count = group.size
          title_with_info = " - Report '#{report.name}' [#{runtime}] #{benchmark_count} tests"
          say title_with_info, :cyan if verbose?(VerbosityLevel::DETAILED)

          progress_bar = Awfy::Views::ProgressBar.new(shell: session.shell, total_benchmarks: benchmark_count, ascii_only: config.ascii_only?)

          benchmarker.run_tests(report, test_name, output: false) do |test, _|
            test_label = results_manager.generate_test_label(test, runtime)
            say "   - #{test_label}", :green if verbose?(VerbosityLevel::DEBUG)
            test.block.call
            progress_bar.increment
          end

          progress_bar.finish
        end
      end
    end
  end
end
