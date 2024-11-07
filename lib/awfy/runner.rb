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

    def start(group, &)
      say_configuration
      configure_benchmark_run
      prepare_output_directory
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
      shell.say
    end

    def configure_benchmark_run
      Singed.output_directory = options.temp_output_directory
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
