# frozen_string_literal: true

module Awfy
  module Jobs
    # Just simply runs the code of the tests, useful for debugging
    class RunGroup < Base
      def call
        if verbose?
          say "> Running the test for:"
          say "> #{group[:name]}...", :cyan
        end

        benchmarker.run_report(group, report_name) do |report, runtime|
          # After defining all benchmark items, set up the progress bar
          benchmark_count = group.size
          title_with_info = "#{group[:name]}/#{report[:name]} [#{runtime}] #{benchmark_count} tests"
          say title_with_info, :cyan if verbose?

          progress_bar = Awfy::Views::ProgressBar.new(@shell, benchmark_count, ascii_only: options.ascii_only?)

          benchmarker.run_tests(report, test_name, output: false) do |test, _|
            test_label = benchmarker.generate_test_label(test, runtime)
            benchmark_job.item(test_label, &test[:block])
            progress_bar&.increment
          end

          progress_bar&.finish
        end
      end
    end
  end
end
