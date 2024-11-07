# frozen_string_literal: true

module Awfy
  class IPS < Command
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

      generate_ips_summary if options[:summary]
    end

    private

    def load_ips_results_json(file_name)
      JSON.parse(File.read(file_name)).map do |result|
        {
          label: result["item"],
          measured_us: result["measured_us"],
          iter: result["iter"],
          stats: Benchmark::IPS::Stats::SD.new(result["samples"]),
          cycles: result["cycles"]
        }
      end
    end

    def generate_ips_summary
      read_reports_for_summary("ips") do |report, results, baseline|
        result_diffs = results.map do |result|
          baseline_stats = baseline[:stats]
          result_stats = result[:stats]
          overlaps = result_stats.overlaps?(baseline_stats)
          diff_x = if baseline_stats.central_tendency > result_stats.central_tendency
            -1.0 * result_stats.speedup(baseline_stats).first
          else
            result_stats.slowdown(baseline_stats).first
          end
          result.merge(
            overlaps: overlaps,
            diff_times: diff_x.round(2)
          )
        end

        result_diffs.sort_by! { |result| -1 * result[:iter] }

        rows = result_diffs.map do |result|
          diff_message = result_diff_message(result)
          test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]

          [result[:branch], result[:runtime], test_name, humanize_scale(result[:stats].central_tendency), diff_message]
        end

        output_summary_table(report, rows, "Branch", "Runtime", "Name", "IPS", "Vs baseline")
      end
    end
  end
end
