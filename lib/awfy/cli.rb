# frozen_string_literal: true

module Awfy
  class CLI < Thor
    include Thor::Actions

    def self.exit_on_failure? = true

    class_option :runtime, enum: ["both", "yjit", "mri"], default: "both", desc: "Run with and/or without YJIT enabled"
    class_option :compare_with, type: :string, desc: "Name of branch to compare with results on current branch"
    class_option :compare_control, type: :boolean, desc: "When comparing branches, also re-run all control blocks too", default: false

    class_option :summary, type: :boolean, desc: "Generate a summary of the results", default: true
    class_option :summary_order, enum: ["desc", "asc", "leader"], default: "leader", desc: "Sort order for summary tables: ascending, descending, or leaderboard (command specific, e.g. fastest to slowest for IPS)"
    class_option :save, type: :boolean, desc: "Save benchmark results to results directory", default: false
    class_option :quiet, type: :boolean, desc: "Silence output. Note if `summary` option is enabled the summaries will be displayed even if `quiet` enabled.", default: false
    class_option :verbose, type: :boolean, desc: "Verbose output", default: false

    class_option :ips_warmup, type: :numeric, default: 1, desc: "Number of seconds to warmup the IPS benchmark"
    class_option :ips_time, type: :numeric, default: 3, desc: "Number of seconds to run the IPS benchmark"
    class_option :temp_output_directory, type: :string, default: "./benchmarks/tmp", desc: "Directory to store temporary output files"
    class_option :results_directory, type: :string, default: "./benchmarks/saved", desc: "Directory to store benchmark results"
    class_option :setup_file_path, type: :string, default: "./benchmarks/setup", desc: "Path to the setup file"
    class_option :tests_path, type: :string, default: "./benchmarks/tests", desc: "Path to the tests files"

    # TODO: implement assert option
    # class_option :assert, type: :boolean, desc: "Assert that the results are within a certain threshold coded in the tests"

    desc "list [GROUP]", "List all tests in a group"
    def list(group = nil)
      runner.start(group) { List.new(shell).list(_1) }
    end

    desc "ips [GROUP] [REPORT] [TEST]", "Run IPS benchmarks. Can generate summary across implementations, runtimes and branches."
    def ips(group = nil, report = nil, test = nil)
      say "Running IPS for:"
      say "> #{requested_tests(group, report, test)}..."

      runner.start(group) { IPS.new(shell, git_client: git_client, options: awfy_options).benchmark(_1, report, test) }
    end

    desc "memory [GROUP] [REPORT] [TEST]", "Run memory profiling. Can generate summary across implementations, runtimes and branches."
    def memory(group = nil, report = nil, test = nil)
      say "Running memory profiling for:"
      say "> #{requested_tests(group, report, test)}..."

      runner.start(group) { Memory.new(shell, git_client: git_client, options: awfy_options).benchmark(_1, report, test) }
    end

    desc "flamegraph GROUP REPORT TEST", "Run flamegraph profiling"
    def flamegraph(group, report, test)
      say "Creating flamegraph for:"
      say "> #{requested_tests(group, report, test)}..."

      runner.start(group) { Flamegraph.new(shell).generate(_1, report, test) }
    end

    desc "profile [GROUP] [REPORT] [TEST]", "Run CPU profiling"
    option :iterations, type: :numeric, default: 1_000_000, desc: "Number of iterations to run the test"
    def profile(group = nil, report = nil, test = nil)
      say "Run profiling of:"
      say "> #{requested_tests(group, report, test)}..."

      runner.start(group) { Profiling.new(shell).generate(_1, report, test) }
    end

    desc "yjit-stats [GROUP] [REPORT] [TEST]", "Run YJIT stats"
    def yjit_stats(group = nil, report = nil, test = nil)
      if options[:runtime] == "mri"
        say_error "Must run with YJIT runtime (if 'both' is selected the command only runs with yjit)"
        exit(1)
      end

      say "Running YJIT stats for:"
      say "> #{requested_tests(group, report, test)}..."

      runner.start(group) { YJITStats.new(shell).benchmark(_1, report, test) }
    end

    desc "clean", "Clean up temporary and saved benchmark results"
    option :saved, type: :boolean, desc: "Also clean saved results", default: false
    def clean
      Dir.glob("#{options[:temp_output_directory]}/*.json").each do |f|
        say "Remove temp file: #{f}" if verbose?
        File.delete(f)
      end
      say "Cleaned temporary results directory"

      if options[:saved]
        Dir.glob("#{options[:results_directory]}/*.json").each do |f|
          say "Remove results file: #{f}", :yellow if verbose?
          File.delete(f)
        end
        say "Cleaned saved results directory"
      end
    end

    private

    def awfy_options
      Options.new(
        verbose: options[:verbose],
        quiet: options[:quiet],
        summary: options[:summary],
        summary_order: options[:summary_order],
        save: options[:save],
        temp_output_directory: options[:temp_output_directory],
        results_directory: options[:results_directory],
        setup_file_path: options[:setup_file_path],
        tests_path: options[:tests_path],
        compare_with_branch: options[:compare_with_branch],
        compare_control: options[:compare_control],
        assert: options[:assert],
        runtime: options[:runtime],
        test_iterations: options[:test_iterations],
        test_time: options[:ips_time],
        test_warm_up: options[:ips_warmup]
      )
    end

    def runner
      @runner ||= Runner.new(Awfy.suite, shell, git_client, awfy_options)
    end

    def requested_tests(group, report = nil, test = nil)
      tests = [group, report, test].compact
      return "(all)" if tests.empty?
      tests.join("/")
    end

    def git_client
      @_git_client ||= ::Git.open(Dir.pwd)
    end

    def git_current_branch_name = git_client.current_branch

    def yjit_only? = options[:runtime] == "yjit"

    def both_runtimes? = options[:runtime] == "both"

    def verbose? = options[:verbose]

    def show_summary? = options[:summary]
  end
end
