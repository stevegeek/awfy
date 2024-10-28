# frozen_string_literal: true

require "fileutils"
require "thor"
require "benchmark/ips"
require "stackprof"
require "singed"
require "memory_profiler"
require "git"
require "json"
require "terminal-table"

module Awfy
  class CLI < Thor
    include Thor::Actions

    CONTROL_MARKER = "[c]"
    TEST_MARKER = "[*]"

    def self.exit_on_failure? = true

    class_option :runtime, enum: ["both", "yjit", "mri"], default: "both", desc: "Run with and/or without YJIT enabled"
    class_option :compare_with, type: :string, desc: "Name of branch to compare with results on current branch"
    class_option :compare_control, type: :boolean, desc: "When comparing branches, also re-run all control blocks too", default: false

    class_option :summary, type: :boolean, desc: "Generate a summary of the results", default: true
    class_option :verbose, type: :boolean, desc: "Verbose output", default: false
    class_option :quiet, type: :boolean, desc: "Silence output", default: false

    class_option :ips_warmup, type: :numeric, default: 1, desc: "Number of seconds to warmup the benchmark"
    class_option :ips_time, type: :numeric, default: 3, desc: "Number of seconds to run the benchmark"
    class_option :temp_output_directory, type: :string, default: "./benchmarks/tmp", desc: "Directory to store temporary output files"
    class_option :setup_file_path, type: :string, default: "./benchmarks/setup", desc: "Path to the setup file"
    class_option :tests_path, type: :string, default: "./benchmarks/tests", desc: "Path to the tests files"

    # TODO: implement assert option
    # class_option :assert, type: :boolean, desc: "Assert that the results are within a certain threshold coded in the tests"

    desc "list [GROUP]", "List all tests in a group"
    def list(group = nil)
      run_pref_test(group) { list_group(_1) }
    end

    desc "ips [GROUP] [REPORT] [TEST]", "Run IPS benchmarks"
    def ips(group = nil, report = nil, test = nil)
      say "Running IPS for:"
      say "> #{requested_tests(group, report, test)}..."

      run_pref_test(group) { run_ips(_1, report, test) }
    end
    #
    # desc "memory [GROUP] [REPORT] [TEST]", "Run memory profiling"
    # def memory(group = nil, report = nil, test = nil)
    #   say "Running memory profiling for:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   run_pref_test(group) { run_memory(_1, report, test) }
    # end
    #
    # desc "flamegraph GROUP REPORT TEST", "Run flamegraph profiling"
    # def flamegraph(group, report, test)
    #   say "Creating flamegraph for:"
    #   say "> #{[group, report, test].join("/")}..."
    #   configure_benchmark_run
    #   run_group(group) { run_flamegraph(_1, report, test) }
    # end
    #
    # # TODO: also YJIT stats output?
    # desc "profile [GROUP] [REPORT] [TEST]", "Run CPU profiling"
    # option :iterations, type: :numeric, default: 1_000_000, desc: "Number of iterations to run the test"
    # def profile(group = nil, report = nil, test = nil)
    #   say "Run profiling of:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   configure_benchmark_run
    #   run_group(group) { run_profiling(_1, report, test) }
    # end

    private

    def say_configuration
      return unless verbose?
      say
      say "| on branch '#{git_client.current_branch}', and #{options[:compare_with] ? "compare with branch: '#{options[:compare_with]}', and " : ""}Runtime: #{options[:runtime].upcase} and assertions: #{options[:assert] || "skip"}", :cyan
      say
    end

    def configure_benchmark_run
      say_configuration

      Singed.output_directory = options[:temp_output_directory]
      expanded_setup_file_path = File.expand_path(options[:setup_file_path], Dir.pwd)
      expanded_tests_path = File.expand_path(options[:tests_path], Dir.pwd)
      test_files = Dir.glob(File.join(expanded_tests_path, "*.rb"))

      require expanded_setup_file_path
      test_files.each { |file| require file }
    end

    def requested_tests(group, report = nil, test = nil)
      tests = [group, report, test].compact
      return "(all)" if tests.empty?
      tests.join("/")
    end

    def run_pref_test(group, &)
      configure_benchmark_run
      if group
        run_group(group, &)
      else
        run_groups(&)
      end
    end

    def run_groups(&)
      current_groups.keys.each do |group_name|
        run_group(group_name, &)
      end
    end

    def current_groups
      @current_groups ||= Awfy.groups.dup.freeze
    end

    def run_group(group_name)
      group = current_groups[group_name]
      raise "Group not found" unless group
      yield group
    end

    def list_group(group)
      say "> #{group[:name]}"
      group[:reports].each do |report|
        say "  - #{report[:name]}"
        report[:tests].each do |test|
          say "    Test: #{test[:name]}"
        end
      end
    end

    def run_ips(group, report_name, test_name)
      if verbose?
        say "> IPS for:"
        say "> #{group[:name]}...", :cyan
      end

      prepare_output_directory_for_ips

      execute_report(group, report_name) do |report, runtime|
        Benchmark.ips(time: options[:ips_time], warmup: options[:ips_warmup], quiet: quiet_steps?) do |bm|
          execute_tests(report, test_name, output: false) do |test, _|
            test_label = "[#{runtime}] #{test[:control] ? CONTROL_MARKER : TEST_MARKER} #{test[:name]}"
            bm.item(test_label, &test[:block])
          end

          # We can persist the results to a file to use to later generate a summary
          save_to(:ips, group, report, runtime) do |file_name|
            bm.save!(file_name)
          end

          bm.compare! if verbose?
        end
      end

      generate_ips_summary if options[:summary]
    end
    #
    # def run_memory(group, report_name, test_name)
    #   say "> Memory profiling for #{group[:name]}...", :cyan if verbose?
    #   execute_report(group, report_name) do |report, runtime|
    #     execute_tests(report, test_name) do |test, _|
    #       MemoryProfiler.report do
    #         test[:block].call
    #       end.pretty_print
    #     end
    #   end
    # end
    #
    # def run_flamegraph(group, report_name, test_name)
    #   execute_report(group, report_name)  do |report, runtime|
    #     execute_tests(report, test_name) do |test, _|
    #       label = "report-#{group[:name]}-#{report[:name]}-#{test[:name]}".gsub(/[^A-Za-z0-9_\-]/, "_")
    #       generate_flamegraph(label) do
    #         test[:block].call
    #       end
    #     end
    #   end
    # end
    #
    # def run_profiling(group, report_name, test_name)
    #   say "> Profiling for #{group[:name]} (iterations: #{options[:iterations]})..." if verbose?
    #   execute_report(group, report_name) do |report, runtime|
    #     execute_tests(report, test_name) do |test, iterations|
    #       data = StackProf.run(mode: :cpu, interval: 100) do
    #         i = 0
    #         while i < iterations
    #           test[:block].call
    #           i += 1
    #         end
    #       end
    #       StackProf::Report.new(data).print_text
    #     end
    #   end
    # end

    def execute_report(group, report_name, &)
      runtime = options[:runtime]
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
      compare_with = options[:compare_with]
      # run on current branch, then checkout to compare branch and run again
      say "| git Branch: '#{git_current_branch_name}'" if verbose?
      execute_group(group, report_name, runtime, &)
      if compare_with
        git_change_branch(compare_with) do
          say "| compare with git Branch: '#{git_current_branch_name}'" if verbose?
          execute_group(group, report_name, runtime, options[:compare_control], &)
        end
      end
    end

    def execute_group(group, report_name, runtime, include_control = true)
      group[:reports].each do |report|
        if report_name
          next unless report[:name] == report_name
        end
        # We dont execute the `control` blocks if include_control is false (eg when we switch branch)
        run_report = report.dup
        run_report[:tests] = report[:tests].reject { |test| test[:control] && !include_control }

        say if verbose?
        say "> --------------------------" if verbose?
        say "> Report (#{runtime} - branch '#{git_current_branch_name}'): #{report[:name]}"
        say "> --------------------------" if verbose?
        say if verbose?
        yield run_report, runtime
        say "<< End Report", :magenta if verbose?
      end
    end

    def execute_tests(report, test_name, output: true, &)
      iterations = options[:iterations] || 1
      sorted_tests = report[:tests].sort { _1[:control] ? -1 : 1 }
      sorted_tests.each do |test|
        if test_name
          next unless test[:name] == test_name
        end
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

    def generate_flamegraph(label = nil, open: true, ignore_gc: false, interval: 1000, &)
      fg = Singed::Flamegraph.new(label: label, ignore_gc: ignore_gc, interval: interval)
      result = fg.record(&)
      fg.save
      fg.open if open
      result
    end

    def prepare_output_directory_for_ips
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
      Dir.glob("#{temp_dir}/*.json").each { |file| File.delete(file) }
    end

    def save_to(type, group, report, runtime)
      current_branch = git_current_branch_name
      file_name = "#{temp_dir}/#{type}-#{runtime}-#{current_branch}-#{group[:name]}-#{report[:name]}.json".gsub(/[^A-Za-z0-9\/_\-.]/, "_")
      say "Saving results to #{file_name}" if verbose?

      awfy_file = "#{temp_dir}/awfy-#{type}-#{group[:name]}-#{report[:name]}.json".gsub(/[^A-Za-z0-9\/_\-.]/, "_")
      awfy_data = JSON.parse(File.read(awfy_file)) if File.exist?(awfy_file)
      awfy_data ||= []
      awfy_data << {type:, group: group[:name], report: report[:name], branch: current_branch, runtime:, output_path: file_name}

      File.write(awfy_file, awfy_data.to_json)
      yield file_name
    end

    def load_json(file_name)
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
      awfy_report_result_files = Dir.glob("#{temp_dir}/awfy-ips-*.json").map do |file_name|
        JSON.parse(File.read(file_name)).map { _1.transform_keys(&:to_sym) }
      end

      awfy_report_result_files.each do |report|
        results = report.map do |single_run|
          load_json(single_run[:output_path]).map do |result|
            test_name = result[:label].match(/\[.{3,4}\] \[.\] (.*)/)[1]
            result.merge!(
              runtime: single_run[:runtime],
              test_name: test_name,
              branch: single_run[:branch]
            )
          end
        end
        results.flatten!(1)

        base_branch = git_current_branch_name
        baseline = results.find do |r|
          r[:branch] == base_branch && r[:label].include?(TEST_MARKER) && r[:runtime] == (yjit_only? ? "yjit" : "mri") # Baseline is mri baseline unless yjit only
        end
        unless baseline
          say_error "Could not work out which result is considered the 'baseline' (ie the `test` case)"
          exit(1)
        end
        baseline[:is_baseline] = true
        say "> Chosen baseline: #{baseline[:label]}" if verbose?

        result_diffs = results.map do |result|
          if baseline
            baseline_stats = baseline[:stats]
            result_stats = result[:stats]
            overlaps = result_stats.overlaps?(baseline_stats)
            diff_x = if baseline_stats.central_tendency > result_stats.central_tendency
              -1.0 * result_stats.speedup(baseline_stats).first
            else
              result_stats.slowdown(baseline_stats).first
            end
          end

          result.merge(
            overlaps: overlaps,
            diff_times: diff_x
          )
        end

        result_diffs.sort_by! { |result| -1 * result[:iter] }

        rows = result_diffs.map do |result|
          diff_message = if result[:is_baseline]
            "-"
          elsif result[:overlaps]
            "same-ish"
          elsif result[:diff_times]
            "#{result[:diff_times].round(2)} x"
          else
            "?"
          end
          test_name = result[:is_baseline] ? "#{result[:test_name]} (baseline)" : result[:test_name]

          [result[:branch], result[:runtime], test_name, result[:stats].central_tendency.round, diff_message]
        end

        group_data = report.first
        table = ::Terminal::Table.new(
          title: "Summary for #{requested_tests(group_data[:group], group_data[:report])}",
          headings: ["Branch", "Runtime", "Name", "IPS", "Diff v baseline (times)"],
          rows: rows
        )

        table.align_column(2, :right)
        table.align_column(3, :right)
        table.align_column(4, :right)

        say table
      end
    end

    def git_client
      @_git_client ||= Git.open(Dir.pwd)
    end

    def git_change_branch(branch)
      # TODO: git to checkout branch (and stash first, then pop after)
      previous_branch = git_current_branch_name
      say "Switching to branch '#{branch}'" if verbose?
      git_client.lib.stash_save("awfy auto stash")
      git_client.checkout(branch)
      yield
    ensure
      say "Switching back to branch '#{previous_branch}'" if verbose?
      git_client.checkout(previous_branch)
      git_client.lib.stash_apply(0)
    end

    def git_current_branch_name = git_client.current_branch

    def yjit_only? = options[:runtime] == "yjit"

    def both_runtimes? = options[:runtime] == "both"

    def temp_dir = options[:temp_output_directory]

    def verbose? = options[:verbose]

    def quiet_steps? = options[:quiet] || options[:summary]
  end
end
