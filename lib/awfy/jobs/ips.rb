# frozen_string_literal: true

require "benchmark/ips"

module Awfy
  module Jobs
    class IPS < Base
      def call
        if verbose?
          say "> IPS for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          Benchmark.ips(time: config.test_time, warmup: config.test_warm_up, quiet: config.show_summary? || verbose?) do |benchmark_job|
            benchmarker.run_tests(report, test_name, output: false) do |test, _|
              test_label = results_manager.generate_test_label(test, runtime)
              benchmark_job.item(test_label, &test.block)
            end

            # After defining all benchmark items, set up the progress bar
            total_benchmarks = benchmark_job.list.size

            if verbose?
              say "> Running #{total_benchmarks} benchmarks", :cyan
            end

            progress_bar = Awfy::Views::TimedProgressBar.new(
              shell: session.shell,
              total_benchmarks:,
              warmup_time: config.test_warm_up,
              test_time: config.test_time,
              ascii_only: config.ascii_only?
            )
            progress_bar.start

            if verbose?
              say "#{group.name}/#{report.name} [#{runtime}] #{total_benchmarks} tests, ~#{progress_bar.estimated_total_time}s", :cyan
              say
            end

            # Use the group_runner to save the results
            results_manager.save_results(:ips, group, report, runtime) do
              # Force the job to run before we save, as normally jobs are run after this block yields
              benchmark_job.load_held_results
              benchmark_job.run

              # The override definition of run to prevent it happening again after this block completes
              # This is a hack but it works
              benchmark_job.define_singleton_method(:run) do
              end

              benchmark_job.full_report.entries.map { |entry| map_data_to_standard_format(entry) }
            end

            # Stop the progress bar once benchmarking is complete
            progress_bar.stop(complete: true)

            # Only show comparison if requested
            if verbose? || !config.show_summary?
              say "> Benchmark comparison:", :cyan unless verbose?
              benchmark_job.compare!
            end
          end
        end

        generate_ips_summary if config.show_summary?
      end

      private

      def map_data_to_standard_format(entry)
        {
          label: entry.label,
          control: results_manager.marked_as_test?(entry),
          measured_us: entry.microseconds,
          iter: entry.iterations,
          samples: entry.samples, # Benchmark::IPS::Stats::SD.new(entry.samples),
          cycles: entry.measurement_cycle
        }
      end

      def generate_ips_summary
        results_manager.load_results(:ips) do |results, baseline|
          Views::IPS::SummaryView.new(session).summary_table(results, baseline)
        end
      end
    end
  end
end
