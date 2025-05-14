# frozen_string_literal: true

require "json"
require "fileutils"

module Awfy
  # Responsible for loading configuration from files with precedence hierarchy
  class ConfigLoader
    CONFIG_FILENAME = ".awfy.json"

    attr_reader :tests_path, :setup_file_path, :test_specific_path

    def initialize(thor_options = {}, explicit_options = {}, tests_path: "./benchmarks", setup_file_path: "./benchmarks/setup", test_specific_path: nil, shell: nil)
      @thor_options = thor_options
      @explicit_options = explicit_options
      @tests_path = tests_path
      @setup_file_path = setup_file_path
      @test_specific_path = test_specific_path
      @shell = shell
    end

    def load_with_precedence
      # Load configs with precedence from lowest to highest
      configs = []

      # Start with thor_options and then layer on the configs.
      # Explicit options are highest precedence

      # Load in order of increasing precedence (last merged has highest precedence)
      home_config = load_from_home
      configs << home_config if home_config

      setup_config = load_from_setup_dir
      configs << setup_config if setup_config

      suite_config = load_from_suite_dir
      configs << suite_config if suite_config

      # Current directory has highest precedence among config files
      current_config = load_from_current_dir
      configs << current_config if current_config

      # Merge all configs from files, starting with the CLI values
      merged_config = @thor_options.dup
      configs.each do |config|
        merged_config.merge!(config)
      end

      # Only merge explicitly set options from CLI (highest precedence)
      merged_config.merge!(@explicit_options)

      if @shell
        @shell.say("Configs loaded: #{configs.inspect}", :cyan)
        @shell.say("Thor options (all): #{@thor_options.inspect}", :cyan)
        @shell.say("Thor options (explicit): #{@explicit_options.inspect}", :cyan)
        @shell.say("Final merged config: #{merged_config.inspect}", :cyan)
      end

      Awfy::Config.new(**merged_config)
    end

    def save(config, location = ConfigLocation::Current)
      path = path_for(location)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      File.write(path, JSON.pretty_generate(config))
      path
    end

    def load(location = ConfigLocation::Current)
      path = path_for(location)
      load_from_file(path)
    end

    def exists?(location = ConfigLocation::Current)
      path = path_for(location)
      File.exist?(path)
    end

    def path_for(location)
      location_enum = ConfigLocation[location] || location

      case location_enum
      when ConfigLocation::Home
        File.join(Dir.home, CONFIG_FILENAME)
      when ConfigLocation::Setup
        setup_dir = File.dirname(File.expand_path(@setup_file_path, Dir.pwd))
        File.join(setup_dir, CONFIG_FILENAME)
      when ConfigLocation::Suite
        File.join(@tests_path, CONFIG_FILENAME)
      when ConfigLocation::Current
        File.join(Dir.pwd, CONFIG_FILENAME)
      else
        if location.is_a?(String)
          directory = File.directory?(location) ? location : File.dirname(location)
          raise ArgumentError, "Invalid location: #{location}" unless File.exist?(directory)
          File.join(directory, CONFIG_FILENAME)
        else
          raise ArgumentError, "Invalid location: #{location}"
        end
      end
    end

    private

    def load_from_home
      path = File.join(Dir.home, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_setup_dir
      setup_dir = File.dirname(File.expand_path(@setup_file_path, Dir.pwd))

      # Skip if setup directory is the same as tests directory or current directory
      tests_dir = File.expand_path(@tests_path, Dir.pwd)
      return nil if setup_dir == tests_dir || setup_dir == Dir.pwd

      path = File.join(setup_dir, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_suite_dir
      path = File.join(@tests_path, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_current_dir
      path = File.join(Dir.pwd, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_file(path)
      return nil unless File.exist?(File.expand_path(path))
      log_config_load(path) if @shell
      begin
        JSON.parse(File.read(path)).transform_keys(&:to_sym)
      rescue JSON::ParserError => e
        warn "Error parsing config file #{path}: #{e.message}"
        nil
      end
    end

    def log_config_load(path)
      relative_path = path.start_with?(Dir.home) ? "~#{path.delete_prefix(Dir.home)}" : path
      @shell.say("Loading config file: #{relative_path}", :cyan)
    end
  end
end
