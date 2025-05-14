# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestConfigLoader < Minitest::Test
    def setup
      @temp_dir = Dir.mktmpdir
      @home_dir = File.join(@temp_dir, "home")
      @suite_dir = File.join(@temp_dir, "benchmarks")
      @current_dir = File.join(@temp_dir, "current")

      # Create directory structure
      FileUtils.mkdir_p(@home_dir)
      FileUtils.mkdir_p(@suite_dir)
      FileUtils.mkdir_p(@current_dir)

      # Store original home directory
      @original_home = ENV["HOME"]
      ENV["HOME"] = @home_dir

      # Create a config loader that uses our test directories
      @config_loader = ConfigLoader.new(tests_path: @suite_dir)
    end

    def teardown
      # Restore original home directory
      ENV["HOME"] = @original_home

      # Clean up temp directories
      FileUtils.remove_entry @temp_dir
    end

    def test_load_config_from_home
      # Create a config file in home directory
      config_data = {runtime: "yjit", verbose: true}
      create_config_file(File.join(@home_dir, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Home)

      # Verify the result
      assert_equal config_data, result
    end

    def test_load_config_from_suite
      # Create a config file in suite directory
      config_data = {runtime: "mri", quiet: true}
      create_config_file(File.join(@suite_dir, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Suite)

      # Verify the result
      assert_equal config_data, result
    end

    def test_load_config_from_current
      # Create a config file in current directory
      config_data = {test_time: 5, test_iterations: 2_000_000}
      create_config_file(File.join(Dir.pwd, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Current)

      # Verify the result
      assert_equal config_data, result
    end

    def test_load_with_precedence
      # Create config files in all locations
      home_config = {runtime: "both", verbose: true}
      suite_config = {runtime: "yjit", quiet: true}
      current_config = {test_time: 5}

      create_config_file(File.join(@home_dir, ".awfy.json"), home_config)
      create_config_file(File.join(@suite_dir, ".awfy.json"), suite_config)
      create_config_file(File.join(Dir.pwd, ".awfy.json"), current_config)

      # Load the merged config
      result = @config_loader.load_with_precedence

      # Higher precedence overrides lower precedence
      expected = home_config.merge(suite_config).merge(current_config)
      assert_equal expected, result
    end

    def test_save_config
      # Create a config to save
      config_data = {runtime: "yjit", test_time: 10}

      # Save to a specific location
      custom_location = File.join(@temp_dir, "custom")
      FileUtils.mkdir_p(custom_location)

      path = @config_loader.save(config_data, custom_location)

      # Verify the file exists and has the right content
      assert File.exist?(path)
      loaded_config = JSON.parse(File.read(path)).transform_keys(&:to_sym)
      assert_equal config_data, loaded_config
    end

    private

    def create_config_file(path, data)
      File.write(path, JSON.generate(data))
    end
  end
end
