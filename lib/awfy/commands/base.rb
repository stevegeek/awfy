# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    # Base class for all benchmark commands
    #
    # Commands::Base provides common functionality used by all benchmark command classes:
    # - Command execution helpers
    # - Shell output utilities
    # - Git operations
    # - Data formatting
    # - Result storage and retrieval
    #
    # All command implementations should inherit from this class to maintain
    # a consistent interface and leverage the shared functionality.
    class Base
      CONTROL_MARKER = "[c]"
      TEST_MARKER = "[*]"

      def initialize(runner, shell, git_client: nil, options: nil)
        @runner = runner
        @shell = shell
        @git_client = git_client
        @options = options
      end

      attr_reader :runner, :options, :git_client

      def say(...) = @shell.say(...)

      def say_error(...) = @shell.say_error(...)

      def verbose? = options.verbose?

      def show_summary? = options.show_summary?

      def generate_test_label(test, runtime)
        "[#{runtime}] #{test[:control] ? CONTROL_MARKER : TEST_MARKER} #{test[:name]}"
      end

      def output_summary_table(report, rows, *headings)
        group_data = report.first
        table = ::Terminal::Table.new(title: table_title(group_data[:group], group_data[:report]), headings: headings)

        rows.each do |row|
          table.add_row(row)
          if row[4] == "-" # FIXME: this is finding the baseline...
            table.add_separator(border_type: :dot3)
          end
        end

        (2...headings.size).each { table.align_column(_1, :right) }

        if options.quiet? && options.show_summary?
          puts table
        else
          say table
          say order_description
        end
      end

      def table_title(group, report = nil, test = nil)
        tests = [group, report, test].compact
        return "Run: (all)" if tests.empty?
        "Run: #{tests.join("/")}"
      end

      def order_description
        say
        case options.summary_order
        when "asc"
          "Results displayed in ascending order"
        when "desc"
          "Results displayed in descending order"
        when "leader"
          "Results displayed as a leaderboard (best to worst)"
        end
      end

      def result_diff_message(result, diff_key = :diff_times)
        if result[:is_baseline]
          "-"
        elsif result[:overlaps] || result[diff_key].zero?
          "same"
        elsif result[diff_key] == Float::INFINITY
          "∞"
        elsif result[diff_key]
          "#{result[diff_key]} x"
        else
          "?"
        end
      end

      SUFFIXES = ["", "k", "M", "B", "T", "Q"].freeze

      def humanize_scale(number, round_to: 0)
        return 0 if number.zero?
        number = number.round(round_to)
        scale = (Math.log10(number) / 3).to_i
        scale = 0 if scale < 0 || scale >= SUFFIXES.size
        suffix = SUFFIXES[scale]
        scaled_value = number.to_f / (1000**scale)
        dp = (scale == 0) ? 0 : 3
        "%10.#{dp}f#{suffix}" % scaled_value
      end

      def execute_report(group, report_name, &)
        runtime = options.runtime
        if runtime == "both" || runtime == "mri"
          say "| run with MRI" if verbose?
          execute_on_branch(group, report_name, "mri", &)
        end
        if runtime == "both" || runtime == "yjit"
          say "| run with YJIT" if verbose?
          raise "YJIT not supported" unless defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)
          RubyVM::YJIT.enable
          execute_on_branch(group, report_name, "yjit", &)
        end
        say if verbose?
      end

      def execute_on_branch(group, report_name, runtime, &)
        # Just execute the group - branch switching is handled by the runner
        execute_group(group, report_name, runtime, true, &)
      end

      def execute_group(group, report_name, runtime, include_control = true)
        reports = report_name ? group[:reports].select { |r| r[:name] == report_name } : group[:reports]

        if reports.empty?
          if report_name
            say_error "Report '#{report_name}' not found in group '#{group[:name]}'"
          else
            say_error "No reports found in group '#{group[:name]}'"
          end
          exit(1)
        end

        reports.each do |report|
          # We dont execute the `control` blocks if include_control is false (eg when we switch branch)
          run_report = report.dup
          run_report[:tests] = report[:tests].reject { |test| test[:control] && !include_control }

          say if verbose?
          say "> --------------------------" if verbose?
          say "> [#{runtime} - branch '#{git_current_branch_name}'] #{group[:name]} / #{report[:name]}", :magenta
          say "> --------------------------" if verbose?
          say if verbose?
          yield run_report, runtime
          say "<< End Report", :magenta if verbose?
        end
      end

      def execute_tests(report, test_name, output: true, &)
        iterations = options.test_iterations || 1
        sorted_tests = report[:tests].sort { _1[:control] ? -1 : 1 }

        tests = test_name ? sorted_tests.select { |t| t[:name] == test_name } : sorted_tests

        if tests.empty?
          if test_name
            say_error "Test '#{test_name}' not found in report '#{report[:name]}'"
          else
            say_error "No tests found in report '#{report[:name]}'"
          end
          exit(1)
        end

        tests.each do |test|
          if output
            say "# ***" if verbose?
            say "# #{test[:control] ? "Control" : "Test"}: #{test[:name]}", :green
            say "# ***" if verbose?
            say
          end
          test[:block].call # run once to lazy load etc
          yield test, iterations
          if output
            say
          end
        end
      end

      # TODO extract this to a separate class and then we can start to refactor, this parses result data into
      # something to pass to view?
      def read_reports_for_summary(type)
        # Create retention policy
        policy = Awfy::RetentionPolicy::Factory.create(options)

        # Get the result store with the policy
        result_store = Awfy::Stores::Factory.instance(options, policy)

        # Get all metadata for this benchmark type
        metadata_entries = result_store.query_results(type:)
        # Group metadata by report (since we need to process each report separately)
        grouped_metadata = metadata_entries.group_by { |entry| [entry.group, entry.report] }

        grouped_metadata.each do |(_group, report_name), report_entries|
          results = report_entries.map do |entry|
            # Load the result data from the ResultMetadata object
            result_data = entry.result_data
            next unless result_data

            # Process each result
            result_data.map do |result|
              # Convert string keys to symbols for backward compatibility
              result = result.transform_keys(&:to_sym) if result.is_a?(Hash)

              # Extract test name from label
              test_name_match = result[:label].match(/\[.{3,4}\] \[.\] (.*)/)
              test_name = test_name_match ? test_name_match[1] : "unknown"

              # Add metadata to the result
              result.merge!(
                runtime: entry.runtime,
                test_name: test_name,
                branch: entry.branch,
                timestamp: entry.timestamp,
                control: result[:control] # Use the control flag from the result itself
              )
            end
          end

          # Flatten and remove nils
          results = results.compact.flatten

          # Skip if no results
          next if results.empty?

          # Choose baseline
          baseline = choose_baseline_test(results)

          # Create report data for the view
          report_data = report_entries.map do |entry|
            {
              "type" => entry.type,
              "group" => entry.group,
              "report" => entry.report,
              "runtime" => entry.runtime,
              "branch" => entry.branch
            }
          end

          # Yield to the block
          yield report_data, results, baseline
        end
      end

      def save_to(type, group, report, runtime)
        ruby_version = RUBY_VERSION
        timestamp = runner.start_time

        # Create metadata for this result using the Result data object
        metadata = Awfy::Result.new(
          type: type,
          group: group[:name],
          report: report[:name],
          runtime: runtime,
          timestamp: timestamp,
          branch: nil,         # Branch info is handled by the runner
          commit: nil,         # Commit info is handled by the runner
          commit_message: nil, # Commit message is handled by the runner
          ruby_version: ruby_version,
          result_id: nil,      # This will be set by the result store
          result_data: nil     # This will be set by the result store
        )

        # Create retention policy
        policy = Awfy::RetentionPolicy::Factory.create(options)

        # Get the result store with the policy
        result_store = Awfy::Stores::Factory.instance(options, policy)

        result_id = result_store.save_result(metadata) do
          yield
        end

        say "Saved results with ID '#{result_id}'" if verbose?

        result_id
      end

      def choose_baseline_test(results)
        # Find the baseline test based on timestamp and runtime
        baseline = results.find do |r|
          r[:timestamp] == runner.start_time && # Must be current run. Previous runs cant be the baseline
            !r[:control] &&
            r[:runtime] == (options.yjit_only? ? "yjit" : "mri") # Baseline is mri baseline unless yjit only
        end
        unless baseline
          say_error "Could not work out which result is considered the 'baseline' (ie the `test` case)"
          exit(1)
        end
        baseline[:is_baseline] = true
        say "> Chosen baseline: #{baseline[:label]}" if verbose?
        baseline
      end
    end
  end
end
