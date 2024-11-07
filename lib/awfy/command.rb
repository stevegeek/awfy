# frozen_string_literal: true

module Awfy
  class Command
    CONTROL_MARKER = "[c]"
    TEST_MARKER = "[*]"

    def initialize(shell, git_client: nil, options: nil)
      @shell = shell
      @git_client = git_client
      @options = options
    end

    attr_reader :options, :git_client

    def say(...) = @shell.say(...)

    def say_error(...) = @shell.say_error(...)

    def git_current_branch_name = git_client.current_branch

    def verbose? = options.verbose?

    def show_summary? = options.show_summary?

    def generate_test_label(test, runtime)
      "[#{runtime}] #{test[:control] ? CONTROL_MARKER : TEST_MARKER} #{test[:name]}"
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
      compare_with = options.compare_with_branch
      # run on current branch, then checkout to compare branch and run again
      say "| git Branch: '#{git_current_branch_name}'" if verbose?
      execute_group(group, report_name, runtime, &)
      if compare_with
        git_change_branch(compare_with) do
          say "| compare with git Branch: '#{git_current_branch_name}'" if verbose?
          execute_group(group, report_name, runtime, options.compare_control?, &)
        end
      end
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

    def read_reports_for_summary(type)
      awfy_report_result_files = Dir.glob("#{options.temp_output_directory}/awfy-#{type}-*.json").map do |file_name|
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

    def save_to(type, group, report, runtime)
      current_branch = git_current_branch_name
      file_name = "#{options.temp_output_directory}/#{type}-#{runtime}-#{current_branch}-#{group[:name]}-#{report[:name]}.json".gsub(/[^A-Za-z0-9\/_\-.]/, "_")
      say "Saving results to #{file_name}" if verbose?

      awfy_file = "#{options.temp_output_directory}/awfy-#{type}-#{group[:name]}-#{report[:name]}.json".gsub(/[^A-Za-z0-9\/_\-.]/, "_")
      awfy_data = JSON.parse(File.read(awfy_file)) if File.exist?(awfy_file)
      awfy_data ||= []
      awfy_data << {type:, group: group[:name], report: report[:name], branch: current_branch, runtime:, output_path: file_name}

      File.write(awfy_file, awfy_data.to_json)
      yield file_name
    end

    def choose_baseline_test(results)
      base_branch = git_current_branch_name
      baseline = results.find do |r|
        r[:branch] == base_branch && r[:label].include?(TEST_MARKER) && r[:runtime] == (options.yjit_only? ? "yjit" : "mri") # Baseline is mri baseline unless yjit only
      end
      unless baseline
        say_error "Could not work out which result is considered the 'baseline' (ie the `test` case)"
        exit(1)
      end
      baseline[:is_baseline] = true
      say "> Chosen baseline: #{baseline[:label]}" if verbose?
      baseline
    end

    def load_results_json(type, file_name)
      send(:"load_#{type}_results_json", file_name)
    end
  end
end
