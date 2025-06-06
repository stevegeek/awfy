# frozen_string_literal: true

require "benchmark/ips"

module Awfy
  module Jobs
    class IPS < Base
      def call
        if verbose?(VerbosityLevel::BASIC)
          say "> IPS for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          Benchmark.ips(time: config.test_time, warmup: config.test_warm_up, quiet: config.show_summary? || verbose?) do |benchmark_job|
            tests = {}
            benchmarker.run_tests(report, test_name, output: false) do |test, _|
              test_label = generate_test_label(test, runtime)
              benchmark_job.item(test_label, &test.block)
              tests[test_label] = test
            end

            # After defining all benchmark items, set up the progress bar
            total_benchmarks = benchmark_job.list.size

            if verbose?(VerbosityLevel::BASIC)
              say "> Running #{total_benchmarks} benchmarks", :cyan
            end

            progress_bar = Awfy::Views::TimedProgressBar.new(
              shell: session.shell,
              total_benchmarks:,
              warmup_time: config.test_warm_up,
              test_time: config.test_time
            )
            progress_bar.start

            if verbose?(VerbosityLevel::DETAILED)
              say "#{group.name}/#{report.name} [#{runtime}] #{total_benchmarks} tests, ~#{"%.1fs" % progress_bar.estimated_total_time}s", :cyan
              say
            end

            # Force the job to run before we save, as normally jobs are run after this block yields
            benchmark_job.load_held_results
            benchmark_job.run

            # The override definition of run to prevent it happening again after this block completes
            # This is a hack but it works
            benchmark_job.define_singleton_method(:run) do
            end

            # At this point we actually have all the results, but to join that returned data back to a test
            # we have to look at the label of the Entry cause BM.item does not actually run the BM at that point
            report_result_data = benchmark_job.full_report.entries.map { |entry| map_result_data_to_standard_format(entry) }

            # Now join back together with test instances
            report_result_data.each do |result_data|
              test = tests[result_data[:mapping_label]]
              # FIXME: signature
              results_manager.save_new_result(:ips, group, report, runtime, test, result_data)
            end

            # Stop the progress bar once benchmarking is complete
            progress_bar.stop(complete: true)

            # Only show comparison if requested
            if verbose?(VerbosityLevel::DEBUG) || !config.show_summary?
              say "> Benchmark comparison:", :cyan unless verbose?(VerbosityLevel::DEBUG)
              benchmark_job.compare!
            end
          end
        end

        generate_ips_summary if config.show_summary?
      end

      private

      def map_result_data_to_standard_format(entry)
        {
          mapping_label: entry.label, # we should not user entry.label as contains the [.] hacks
          control: marked_as_control?(entry),
          baseline: marked_as_baseline?(entry),
          measured_us: entry.microseconds,
          iter: entry.iterations,
          samples: entry.samples, # Benchmark::IPS::Stats::SD.new(entry.samples),
          cycles: entry.measurement_cycle
        }
      end

      def generate_ips_summary
        results_manager.each_report(:ips) do |results, baseline|
          Views::IPS::SummaryView.new(
            group_name: group.name,
            report_name:,
            test_name:,
            session:,
            results:,
            baseline:
          ).render
        end
      end
    end
  end
end
