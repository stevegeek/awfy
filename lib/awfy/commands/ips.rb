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
          Benchmark.ips(time: options.test_time, warmup: options.test_warm_up, quiet: show_summary? || verbose?) do |bm|
            execute_tests(report, test_name, output: false) do |test, _|
              test_label = generate_test_label(test, runtime)
              bm.item(test_label, &test[:block])
            end

            # We can persist the results to a file to use to later generate a summary
            save_to(:ips, group, report, runtime) do |file_name|
              bm.save!(file_name)
            end

            bm.compare! if verbose? || !show_summary?
          end
        end

        generate_ips_summary if show_summary?
      end

      private

      def load_ips_results_json(file_name)
        JSON.parse(File.read(file_name)).map do |result|
          {
            label: result["item"],
            control: result["item"].include?(TEST_MARKER),
            measured_us: result["measured_us"],
            iter: result["iter"],
            stats: Benchmark::IPS::Stats::SD.new(result["samples"]),
            cycles: result["cycles"]
          }
        end
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
