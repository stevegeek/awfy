# frozen_string_literal: true

module Awfy
  module Commands
    class IPS < Base
      def benchmark(group, report_name, test_name)
        if verbose?
          say "> IPS for:"
          say "> #{group[:name]}...", :cyan
        end

        execute_report(group, report_name) do |report, runtime|
          Benchmark.ips(time: options.test_time, warmup: options.test_warm_up, quiet: show_summary? || verbose?) do |benchmark_job|
            execute_tests(report, test_name, output: false) do |test, _|
              test_label = generate_test_label(test, runtime)
              benchmark_job.item(test_label, &test[:block])
            end

            # We can persist the results to a file to use to later generate a summary
            save_to(:ips, group, report, runtime) do
              # Force the job to run before we save, as normally jobs are run after this block yields
              benchmark_job.load_held_results
              benchmark_job.run

              # The override definition of run to prevent it happening again after this block completes
              # This is a hack but it works
              benchmark_job.define_singleton_method(:run) do
              end

              benchmark_job.full_report.entries.map { |entry| map_data_to_standard_format(entry) }
            end

            benchmark_job.compare! if verbose? || !show_summary?
          end
        end

        generate_ips_summary if show_summary?
      end

      private

      def map_data_to_standard_format(entry)
        {
          label: entry.label,
          control: entry.label.include?(TEST_MARKER),
          measured_us: entry.microseconds,
          iter: entry.iterations,
          samples: entry.samples, # Benchmark::IPS::Stats::SD.new(entry.samples),
          cycles: entry.measurement_cycle
        }
      end

      def generate_ips_summary
        view = Views::IPS::CompositeView.new(@shell, options)

        # Process reports and use the view to display
        read_reports_for_summary("ips") do |report, results, baseline|
          view.summary_table(report, results, baseline)
        end
      end
    end
  end
end
