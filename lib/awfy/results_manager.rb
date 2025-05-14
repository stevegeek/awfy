# frozen_string_literal: true

module Awfy
  class ResultsManager < Literal::Object
    include HasSession

    def after_initialize
      @start_time = Time.now
      @store = Awfy::Stores.create(
        config.storage_backend,
        config.storage_name,
        config.current_retention_policy
      )
      run_cleanup_with_retention_policy
    end

    def save_new_result(type, group, report, runtime, test, result_data, commit_hash: nil, commit_message: nil, branch: nil)
      result = Result.new(
        control: test.control?,
        baseline: test.baseline?,
        type:,
        group_name: group.name,
        report_name: report.name,
        runtime:,
        timestamp: start_time,
        branch:,
        commit_hash:,
        commit_message:,
        ruby_version: RUBY_VERSION,
        result_data:
      )
      store.save_result(result)

      say "Saved results with Result ID '#{result.result_id}'" if verbose?

      result.result_id
    end

    # Read and process results for a specific benchmark type
    def each_report(type)
      entries = store.query_results(type:)
      by_report = entries.group_by { |entry| [entry.group_name, entry.report_name] }

      by_report.each do |(group_name, report_name), results|
        next if results.empty?

        baseline = choose_baseline_test(group_name, report_name, results)
        yield results, baseline
      end
    end

    private

    attr_reader :store, :start_time

    # Run cleanup with the current retention policy
    # This ensures old results are cleaned up before each benchmark run
    def run_cleanup_with_retention_policy
      say "| Cleaning old results..." if verbose?
      store.clean_results
      say "| Applied '#{store.retention_policy.name}' retention policy\n" if verbose?
    end

    # Choose the baseline test from a set of results, as the most recent for given runtime
    def choose_baseline_test(group_name, report_name, results)
      candidates = results.filter do |r|
        r.runtime == (config.yjit_only? ? Runtimes::YJIT : Runtimes::MRI) # Baseline is mri baseline unless yjit only
      end
      baseline = candidates.sort_by(&:timestamp).reverse.filter(&:baseline?).first

      raise Errors::NoBaselineError, "Could not determine the 'test' in #{group_name}/#{report_name}. Are you sure your benchmark group has a 'test' definition?" unless baseline

      say "> Chosen test to compare against: #{baseline.label}" if verbose?
      baseline
    end
  end
end
