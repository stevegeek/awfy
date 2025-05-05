# frozen_string_literal: true

require "fileutils"

module Awfy
  class Runner
    def initialize(suite, shell, git_client, options)
      @shell = shell
      @git_client = git_client
      @suite = suite
      @options = options
      @groups = suite.groups
    end

    attr_reader :start_time

    def start(group, &)
      @start_time = Time.now.to_i
      say_configuration
      configure_benchmark_run
      prepare_output_directory
      run_cleanup_with_retention_policy
      if group
        run_group(group, &)
      else
        run_groups(&)
      end
    end

    def run_groups(&)
      @groups.keys.each do |group_name|
        run_group(group_name, &)
      end
    end

    def run_group(group_name, &)
      group = @groups[group_name]
      raise "Group '#{group_name}' not found" unless group
      yield group
    end

    private

    attr_reader :shell, :git_client, :options

    def say_configuration
      return unless options.verbose?
      shell.say
      shell.say "| on branch '#{git_client.current_branch}', and #{options.compare_with_branch ? "compare with branch: '#{options.compare_with_branch}', and " : ""}Runtime: #{options.humanized_runtime} and assertions: #{options.assert? || "skip"}", :cyan
      shell.say "| Timestamp #{@start_time}", :cyan

      # Terminal capability detection and display
      term = ENV["TERM"] || "not set"
      lang = ENV["LANG"] || "not set"
      no_color = ENV["NO_COLOR"] || "not set"
      stdout_tty = $stdout.tty?

      # Check for Unicode support
      term_unicode = (term.include?("xterm") || term.include?("256color") ||
                      lang.include?("UTF") || lang.include?("utf")) ? "likely" : "unlikely"
      # Check for color support
      term_color = if no_color != "not set"
        "disabled by env"
      elsif !stdout_tty
        "disabled (not a TTY)"
      else
        (term.include?("color") || term == "xterm") ? "likely" : "unlikely"
      end

      shell.say "| Display: " +
        "#{options.classic_style? ? "classic style" : "modern style"}, " +
        "Unicode: #{options.ascii_only? ? "disabled by flag" : term_unicode} [TERM=#{term}, LANG=#{lang}], " +
        "Color: #{options.no_color? ? "disabled by flag" : term_color} [NO_COLOR=#{(no_color == "not set") ? "not set" : "set"}, TTY=#{stdout_tty}]", :cyan

      # Display progress bar information
      shell.say "| Progress bar: #{options.test_warm_up}s warmup + #{options.test_time}s runtime per test", :cyan
      shell.say
    end

    def configure_benchmark_run
      expanded_setup_file_path = File.expand_path(options.setup_file_path, Dir.pwd)
      expanded_tests_path = File.expand_path(options.tests_path, Dir.pwd)
      test_files = Dir.glob(File.join(expanded_tests_path, "*.rb"))

      require expanded_setup_file_path
      test_files.each { |file| require file }
    end

    def prepare_output_directory
      temp_dir = options.temp_output_directory
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
      Dir.glob("#{temp_dir}/*.json").each { |file| File.delete(file) }

      results_dir = options.results_directory
      FileUtils.mkdir_p(results_dir) unless Dir.exist?(results_dir)
    end
  end
end
