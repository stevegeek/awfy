# frozen_string_literal: true

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
    class_option :quiet, type: :boolean, desc: "Silence output. Note if `summary` option is enabled the summaries will be displayed even if `quiet` enabled.", default: false
    class_option :verbose, type: :boolean, desc: "Verbose output", default: false

    class_option :ips_warmup, type: :numeric, default: 1, desc: "Number of seconds to warmup the IPS benchmark"
    class_option :ips_time, type: :numeric, default: 3, desc: "Number of seconds to run the IPS benchmark"
    class_option :temp_output_directory, type: :string, default: "./benchmarks/tmp", desc: "Directory to store temporary output files"
    class_option :setup_file_path, type: :string, default: "./benchmarks/setup", desc: "Path to the setup file"
    class_option :tests_path, type: :string, default: "./benchmarks/tests", desc: "Path to the tests files"

    # TODO: implement assert option
    # class_option :assert, type: :boolean, desc: "Assert that the results are within a certain threshold coded in the tests"

    desc "list [GROUP]", "List all tests in a group"
    def list(group = nil)
      runner.start(group) { List.perform(_1, shell) }
    end

    desc "ips [GROUP] [REPORT] [TEST]", "Run IPS benchmarks. Can generate summary across implementations, runtimes and branches."
    def ips(group = nil, report = nil, test = nil)
      say "Running IPS for:"
      say "> #{requested_tests(group, report, test)}..."

      run_pref_test(group) { run_ips(_1, report, test) }
    end

    desc "memory [GROUP] [REPORT] [TEST]", "Run memory profiling. Can generate summary across implementations, runtimes and branches."
    def memory(group = nil, report = nil, test = nil)
      say "Running memory profiling for:"
      say "> #{requested_tests(group, report, test)}..."

      run_pref_test(group) { run_memory(_1, report, test) }
    end

    desc "flamegraph GROUP REPORT TEST", "Run flamegraph profiling"
    def flamegraph(group, report, test)
      say "Creating flamegraph for:"
      say "> #{[group, report, test].join("/")}..."

      configure_benchmark_run
      run_group(group) { run_flamegraph(_1, report, test) }
    end

    # # TODO: also YJIT stats output?
    desc "profile [GROUP] [REPORT] [TEST]", "Run CPU profiling"
    option :iterations, type: :numeric, default: 1_000_000, desc: "Number of iterations to run the test"
    def profile(group = nil, report = nil, test = nil)
      say "Run profiling of:"
      say "> #{requested_tests(group, report, test)}..."

      configure_benchmark_run
      run_group(group) { run_profiling(_1, report, test) }
    end

    private

    def awfy_options
      Options.new(
        verbose: options[:verbose],
        temp_output_directory: options[:temp_output_directory],
        setup_file_path: options[:setup_file_path],
        tests_path: options[:tests_path],
        compare_with_branch: options[:compare_with_branch],
        assert: options[:assert],
        runtime: options[:runtime]
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

    def run_pref_test(group, &)
      configure_benchmark_run
      prepare_output_directory
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

      execute_report(group, report_name) do |report, runtime|
        Benchmark.ips(time: options[:ips_time], warmup: options[:ips_warmup], quiet: show_summary? || verbose?) do |bm|
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

    def generate_test_label(test, runtime)
      "[#{runtime}] #{test[:control] ? CONTROL_MARKER : TEST_MARKER} #{test[:name]}"
    end

    def run_memory(group, report_name, test_name)
      if verbose?
        say "> Memory profiling for:"
        say "> #{group[:name]}...", :cyan
      end
      execute_report(group, report_name) do |report, runtime|
        results = []
        execute_tests(report, test_name) do |test, _|
          data = MemoryProfiler.report do
            test[:block].call
          end
          test_label = generate_test_label(test, runtime)
          results << {
            label: test_label,
            data: data
          }
          data.pretty_print if verbose?
        end

        save_to(:memory, group, report, runtime) do |file_name|
          save_memory_profile_report_to_file(file_name, results)
        end
      end

      generate_memory_summary if options[:summary]
    end

    def run_flamegraph(group, report_name, test_name)
      execute_report(group, report_name) do |report, runtime|
        execute_tests(report, test_name) do |test, _|
          label = "report-#{group[:name]}-#{report[:name]}-#{test[:name]}".gsub(/[^A-Za-z0-9_\-]/, "_")
          generate_flamegraph(label) do
            test[:block].call
          end
        end
      end
    end

    def run_profiling(group, report_name, test_name)
      if verbose?
        say "> Profiling for:"
        say "> #{group[:name]} (iterations: #{options[:iterations]})...", :cyan
      end
      execute_report(group, report_name) do |report, runtime|
        execute_tests(report, test_name) do |test, iterations|
          data = StackProf.run(mode: :cpu, interval: 100) do
            i = 0
            while i < iterations
              test[:block].call
              i += 1
            end
          end
          StackProf::Report.new(data).print_text
        end
      end
    end

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
        say "> [#{runtime} - branch '#{git_current_branch_name}'] #{group[:name]} / #{report[:name]}", :magenta
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

    def prepare_output_directory
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
      Dir.glob("#{temp_dir}/*.json").each { |file| File.delete(file) }
    end

    def save_memory_profile_report_to_file(file_name, results)
      data = results.map do |label_and_data|
        result = label_and_data[:data]
        {
          label: label_and_data[:label],
          total_allocated_memory: result.total_allocated_memsize,
          total_retained_memory: result.total_retained_memsize,
          # Individual results, arrays of objects {count: numeric, data: string}
          allocated_memory_by_gem: result.allocated_memory_by_gem,
          retained_memory_by_gem: result.retained_memory_by_gem,
          allocated_memory_by_file: result.allocated_memory_by_file,
          retained_memory_by_file: result.retained_memory_by_file,
          allocated_memory_by_location: result.allocated_memory_by_location,
          retained_memory_by_location: result.retained_memory_by_location,
          allocated_memory_by_class: result.allocated_memory_by_class,
          retained_memory_by_class: result.retained_memory_by_class,
          allocated_objects_by_gem: result.allocated_objects_by_gem,
          retained_objects_by_gem: result.retained_objects_by_gem,
          allocated_objects_by_file: result.allocated_objects_by_file,
          retained_objects_by_file: result.retained_objects_by_file,
          allocated_objects_by_location: result.allocated_objects_by_location,
          retained_objects_by_location: result.retained_objects_by_location,
          allocated_objects_by_class: result.allocated_objects_by_class,
          retained_objects_by_class: result.retained_objects_by_class
        }
      end
      File.write(file_name, data.to_json)
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

    def load_results_json(type, file_name)
      case type
      when "ips"
        load_ips_results_json(file_name)
      when "memory"
        load_memory_results_json(file_name)
      else
        raise "Unknown test type"
      end
    end

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

    def load_memory_results_json(file_name)
      JSON.parse(File.read(file_name)).map { _1.transform_keys(&:to_sym) }
    end

    def choose_baseline_test(results)
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
      baseline
    end

    def generate_memory_summary
      read_reports_for_summary("memory") do |report, results, baseline|
        result_diffs = results.map do |result|
          overlaps = result[:total_allocated_memory] == baseline[:total_allocated_memory] && result[:total_retained_memory] == baseline[:total_retained_memory]
          diff_x = if baseline[:total_allocated_memory].zero? && !result[:total_allocated_memory].zero?
            Float::INFINITY
          elsif baseline[:total_allocated_memory].zero?
            0.0
          elsif baseline[:total_allocated_memory] > result[:total_allocated_memory]
            -1.0 * result[:total_allocated_memory] / baseline[:total_allocated_memory]
          else
            result[:total_allocated_memory].to_f / baseline[:total_allocated_memory]
          end
          retained_diff_x = if baseline[:total_retained_memory].zero? && !result[:total_retained_memory].zero?
            Float::INFINITY
          elsif baseline[:total_retained_memory].zero?
            0.0
          elsif baseline[:total_retained_memory] > result[:total_retained_memory]
            -1.0 * result[:total_retained_memory] / baseline[:total_retained_memory]
          else
            result[:total_retained_memory].to_f / baseline[:total_retained_memory]
          end
          result.merge(
            overlaps: overlaps,
            diff_times: diff_x.round(2),
            retained_diff_times: retained_diff_x.round(2)
          )
        end

        result_diffs.sort_by! { |result| -1 * result[:diff_times] }

        rows = result_diffs.map do |result|
          diff_message = result_diff_message(result)
          retained_message = result_diff_message(result, :retained_diff_times)
          test_name = result[:is_baseline] ? "(baseline) #{result[:test_name]}" : result[:test_name]
          [result[:branch], result[:runtime], test_name, humanize_scale(result[:total_allocated_memory]), diff_message, humanize_scale(result[:total_retained_memory]), retained_message]
        end

        output_summary_table(report, rows, "Branch", "Runtime", "Name", "Total Allocations", "Vs baseline", "Total Retained", "Vs baseline")
      end
    end

    def output_summary_table(report, rows, *headings)
      group_data = report.first
      table = ::Terminal::Table.new(title: requested_tests(group_data[:group], group_data[:report]), headings: headings)

      rows.each do |row|
        table.add_row(row)
        if row[4] == "-" # FIXME: this is finding the baseline...
          table.add_separator(border_type: :dot3)
        end
      end

      (2...headings.size).each { table.align_column(_1, :right) }

      if options[:quiet] && options[:summary]
        puts table
      else
        say table
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

    def read_reports_for_summary(type)
      awfy_report_result_files = Dir.glob("#{temp_dir}/awfy-#{type}-*.json").map do |file_name|
        JSON.parse(File.read(file_name)).map { _1.transform_keys(&:to_sym) }
      end

      awfy_report_result_files.each do |report|
        results = report.map do |single_run|
          load_results_json(type, single_run[:output_path]).map do |result|
            test_name = result[:label].match(/\[.{3,4}\] \[.\] (.*)/)[1]
            result.merge!(
              runtime: single_run[:runtime],
              test_name: test_name,
              branch: single_run[:branch]
            )
          end
        end
        results.flatten!(1)
        baseline = choose_baseline_test(results)

        yield report, results, baseline
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
      # Git client does not have a pop method so send our own command
      git_client.lib.send(:command, "stash", "pop")
    end

    def git_current_branch_name = git_client.current_branch

    def yjit_only? = options[:runtime] == "yjit"

    def both_runtimes? = options[:runtime] == "both"

    def temp_dir = options[:temp_output_directory]

    def verbose? = options[:verbose]

    def show_summary? = options[:summary]
  end
end
