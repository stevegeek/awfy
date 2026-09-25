# frozen_string_literal: true

require "time"
require "tmpdir"

module Awfy
  module Commands
    # `awfy run`: loads the setup file and one suite file, measures every selected test with
    # the pass runner, saves one :measure result per test with the run meta, checks the
    # suite's performance assertions against it and returns the document. A test that raises
    # or fails an assertion is listed under "failures"; a failed assertion still saves the result.
    class Run < Base
      prop :suite_path, String, reader: :private
      prop :label, _Nilable(String), reader: :private
      prop :collector_keys, _Array(String), reader: :private
      prop :artefacts_dir, _Nilable(String), reader: :private

      def run
        suite = Suites::Loader.new(session:, group_names:, suite_path:).load
        collectors = collector_keys.uniq.map { Collectors.fetch(it) }
        resolve_isolations!(suite)
        git_info = git_client.info
        run_label = label || git_info[:branch] || "unlabelled"
        started_at = Time.now
        meta = result_meta
        runner = PassRunner.new(collectors:, label: run_label,
          artefacts_dir: artefacts_dir || File.join(Dir.tmpdir, "awfy-artefacts"))

        results = []
        failures = []
        each_test(suite) do |group, report, test|
          measurement = runner.measure(group, report, test)
          save(measurement, test, run_label, started_at, git_info, meta)
          results << measurement.to_json_hash
          broken = report.assertions_within(group).filter_map { it.failure(measurement.collectors) }
          failures << failure(group, report, test, "Assertion failed: #{broken.join("; ")}") if broken.any?
        rescue => e
          failures << failure(group, report, test, "#{e.class}: #{e.message}")
        end
        raise Errors::SuiteEmptyError, "No test in '#{suite_path}' matched the selection" if results.empty? && failures.empty?

        {
          "awfy" => VERSION, "label" => run_label, "started_at" => started_at.utc.iso8601,
          "meta" => RunMeta.snapshot, "results" => results, "failures" => failures
        }
      end

      private

      # Resolved for every selected test before the first call, like Collectors.fetch above:
      # an unavailable isolation strategy aborts the whole run with one clear error,
      # instead of only surfacing mid-run once some earlier tests already had side effects.
      def resolve_isolations!(suite)
        each_test(suite) { |group, report, _test| Isolation.resolve(report.hooks.isolate || group.hooks.isolate) }
      end

      def failure(group, report, test, error)
        {"group" => group.name, "report" => report.name, "test" => test.name, "error" => error}
      end

      def each_test(suite)
        suite.groups.each do |group|
          reports = report_name ? group.reports.select { it.name == report_name } : group.reports
          reports.each do |report|
            report.tests_sorted_by_type(test_name:).each { |test| yield group, report, test }
          end
        end
      end

      # The run meta saved with each result, so `awfy compare` can flag environment differences.
      # Taken after the setup file ran, as it may boot Rails. The pid is left out: it differs on
      # every run.
      def result_meta = RunMeta.snapshot.except("pid").merge("awfy" => VERSION)

      def save(measurement, test, run_label, started_at, git_info, meta)
        session.results_store.save_result(MeasureResult.new(
          type: :measure, control: test.control?, baseline: test.baseline?,
          group_name: measurement.group_name, report_name: measurement.report_name, test_name: measurement.test_name,
          runtime: current_runtime, timestamp: started_at, run_label:,
          branch: git_info[:branch], commit_hash: git_info[:commit_hash], commit_message: git_info[:commit_message],
          result_data: measurement.result_data.merge("meta" => meta)
        ))
      end

      def current_runtime
        (RubyVM.const_defined?(:YJIT) && RubyVM::YJIT.enabled?) ? Runtimes::YJIT : Runtimes::MRI
      end
    end
  end
end
