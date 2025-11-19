# frozen_string_literal: true

module Awfy
  module Jobs
    class YJITStats < Base
      def call
        unless defined?(RubyVM::YJIT)
          say_error "YJIT is not available in this Ruby build"
          exit(1)
        end

        unless RubyVM::YJIT.enabled?
          say_error "YJIT must be enabled to collect stats. Run with --yjit flag"
          exit(1)
        end

        if verbose?(VerbosityLevel::BASIC)
          say "> YJIT stats for:"
          say "> #{group.name}...", :cyan
        end

        benchmarker.run(group, report_name) do |report, runtime|
          total_tests = report.tests.size

          if verbose?(VerbosityLevel::BASIC)
            say "> Running #{total_tests} YJIT stats collections", :cyan
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

          results = []
          benchmarker.run_tests(report, test_name, output: false) do |test, _|
            if verbose?(VerbosityLevel::DEBUG)
              say "# ***"
              say "# #{test.control? ? "Control" : "Test"}: #{test.name}", :green
              say "# ***"
              say
            end

            # Reset YJIT stats before test
            RubyVM::YJIT.reset_stats

            # Run the test
            test.block.call

            # Collect stats
            stats = RubyVM::YJIT.stats

            if verbose?(VerbosityLevel::DEBUG)
              say "YJIT Stats:"
              stats.each do |key, value|
                say "  #{key}: #{value}"
              end
              say
            end

            results << {
              test:,
              stats:
            }

            progress_bar.increment
          end

          progress_bar.finish

          # Get current git information to store with results
          git_info = current_git_info

          # Save results
          results.each do |result|
            results_manager.save_new_result(:yjit_stats, group, report, runtime, result[:test], result[:stats], **git_info)
          end
        end

        generate_yjit_summary if config.show_summary?
      end

      private

      def generate_yjit_summary
        results_manager.each_report(:yjit_stats) do |results, baseline|
          Views::YJITStats::SummaryView.new(session:).summary_table(results, baseline)
        end
      end
    end
  end
end
