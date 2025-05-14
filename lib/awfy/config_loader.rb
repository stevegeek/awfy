# frozen_string_literal: true

require "json"
require "fileutils"

module Awfy
  # Configuration file locations
  class ConfigLocation < Literal::Enum(String)
    Home = new("home")
    Suite = new("suite")
    Current = new("current")
  end

  # Responsible for loading configuration from files with precedence hierarchy
  class ConfigLoader
    CONFIG_FILENAME = ".awfy.json"

    attr_reader :tests_path

    def initialize(tests_path: "./benchmarks")
      @tests_path = tests_path
    end

    def load_with_precedence
      # Load configs with precedence from lowest to highest
      configs = []

      home_config = load_from_home
      configs << home_config if home_config

      suite_config = load_from_suite_dir
      configs << suite_config if suite_config

      current_config = load_from_current_dir
      configs << current_config if current_config

      merged_config = {}
      configs.each do |config|
        merged_config.merge!(config)
      end

      merged_config
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

    def load_from_suite_dir
      path = File.join(@tests_path, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_current_dir
      path = File.join(Dir.pwd, CONFIG_FILENAME)
      load_from_file(path)
    end

    def load_from_file(path)
      return nil unless File.exist?(path)

      begin
        JSON.parse(File.read(path)).transform_keys(&:to_sym)
      rescue JSON::ParserError => e
        warn "Error parsing config file #{path}: #{e.message}"
        nil
      end
    end
  end
end
