# frozen_string_literal: true

require "benchmark/ips"

module Awfy
  module Commands
    class Results < Base
      prop :type, _Nilable(Symbol), reader: :private

      # List all stored benchmark results
      def list
        results = results_store.query_results(type: type)

        if results.empty?
          session.say "No benchmark results found in storage."
          return
        end

        # Group results by type and group/report
        by_type_and_report = results.group_by do |result|
          [result.type, result.group_name, result.report_name]
        end

        session.say "\n=== Stored Benchmark Results ==="
        session.say "Storage: #{config.storage_backend} (#{config.storage_name})\n\n"

        # Sort by type and group/report name
        by_type_and_report.sort.each do |(result_type, group_name, report_name), report_results|
          count = report_results.size
          latest = report_results.max_by(&:timestamp)

          type_label = result_type.to_s.upcase
          session.say "#{type_label}: #{group_name}/#{report_name}"
          session.say "  Results: #{count}"
          session.say "  Latest: #{latest.timestamp.strftime('%Y-%m-%d %H:%M:%S')}"
          session.say "  Branch: #{latest.branch || 'unknown'}"
          session.say ""
        end

        session.say "Total: #{results.size} result(s) across #{by_type_and_report.size} report(s)"
      end

      # Show detailed results for a specific group/report
      def show
        unless group_names && group_names.any?
          session.say_error "Error: GROUP name is required"
          session.say "Usage: awfy results show GROUP [REPORT]"
          return
        end

        group_name = group_names.first

        # Query results for the specified group and report
        query_params = {group_name: group_name}
        query_params[:report_name] = report_name if report_name
        query_params[:type] = type if type

        results = results_store.query_results(**query_params)

        if results.empty?
          session.say "No results found for #{group_name}#{report_name ? "/#{report_name}" : ""}"
          return
        end

        # Generate summaries for each type and report
        results_by_type_and_report = results.group_by do |result|
          [result.type, result.report_name]
        end

        results_by_type_and_report.sort.each do |(result_type, current_report_name), report_results|
          generate_summary(result_type, group_name, current_report_name, report_results)
        end
      end

      private

      def generate_summary(result_type, group_name, report_name, results)
        # Choose baseline (most recent baseline for the appropriate runtime)
        baseline = choose_baseline(results)

        unless baseline
          session.say "Warning: No baseline found for #{group_name}/#{report_name}"
          return
        end

        # Generate the appropriate summary view based on result type
        case result_type
        when :ips
          view = Views::IPS::SummaryView.new(
            session: session,
            group_name: group_name,
            report_name: report_name,
            test_name: test_name,
            results: results,
            baseline: baseline
          )
          view.render
        when :memory
          view = Views::Memory::SummaryView.new(
            session: session,
            group_name: group_name,
            report_name: report_name,
            test_name: test_name,
            results: results,
            baseline: baseline
          )
          view.render
        else
          session.say "Warning: Unknown result type '#{result_type}'"
        end
      end

      def choose_baseline(results)
        # Choose baseline similar to ResultsManager
        runtime_for_baseline = config.yjit_only? ? Runtimes::YJIT : Runtimes::MRI

        candidates = results.filter do |r|
          r.runtime == runtime_for_baseline
        end

        candidates.sort_by(&:timestamp).reverse.find(&:baseline?)
      end

      def results_store
        session.results_store
      end
    end
  end
end
