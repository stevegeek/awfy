# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestConfigLoader < Minitest::Test
    def setup
      @temp_dir = Dir.mktmpdir
      @home_dir = File.join(@temp_dir, "home")
      @suite_dir = File.join(@temp_dir, "benchmarks/tests")
      @setup_dir = File.join(@temp_dir, "benchmarks/setup")
      @current_dir = File.join(@temp_dir, "current")

      # Create directory structure
      FileUtils.mkdir_p(@home_dir)
      FileUtils.mkdir_p(@suite_dir)
      FileUtils.mkdir_p(@setup_dir)
      FileUtils.mkdir_p(@current_dir)

      # Store original home directory
      @original_home = ENV["HOME"]
      ENV["HOME"] = @home_dir

      # Create a config loader that uses our test directories
      @config_loader = ConfigLoader.new(
        {}, # Empty thor_options
        {}, # Empty explicit_options
        tests_path: @suite_dir,
        setup_file_path: File.join(@setup_dir, "setup.rb")
      )
    end

    def teardown
      # Restore original home directory
      ENV["HOME"] = @original_home

      # Clean up temp directories
      FileUtils.remove_entry @temp_dir
    end

    def test_load_config_from_home
      # Create a config file in home directory
      config_data = {runtime: "yjit", verbose: VerbosityLevel::BASIC.value}
      create_config_file(File.join(@home_dir, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Home)

      # Verify the result
      assert_equal config_data.transform_keys(&:to_sym), result.transform_keys(&:to_sym)
    end

    def test_load_config_from_suite
      # Create a config file in suite directory
      config_data = {runtime: "mri", verbose: VerbosityLevel::MUTE.value}
      create_config_file(File.join(@suite_dir, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Suite)

      # Verify the result
      assert_equal config_data.transform_keys(&:to_sym), result.transform_keys(&:to_sym)
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

    def test_load_config_from_setup
      # Create a config file in setup directory
      config_data = {test_warm_up: 2.5, summary_order: "asc"}
      create_config_file(File.join(@setup_dir, ".awfy.json"), config_data)

      # Load the config
      result = @config_loader.load(ConfigLocation::Setup)

      # Verify the result
      assert_equal config_data, result
    end

    def test_load_with_precedence
      # Create config files in all locations
      home_config = {runtime: "both", verbose: VerbosityLevel::BASIC.value}
      setup_config = {test_warm_up: 2.5, summary_order: "asc"}
      suite_config = {runtime: "yjit", verbose: VerbosityLevel::MUTE.value}
      current_config = {test_time: 5}

      create_config_file(File.join(@home_dir, ".awfy.json"), home_config)
      create_config_file(File.join(@setup_dir, ".awfy.json"), setup_config)
      create_config_file(File.join(@suite_dir, ".awfy.json"), suite_config)
      create_config_file(File.join(Dir.pwd, ".awfy.json"), current_config)

      # Load the merged config
      result = @config_loader.load_with_precedence

      # Test key values from the merged config (higher precedence overrides lower precedence)
      assert_equal "yjit", result.runtime, "Expected runtime from suite config"
      # Suite config's MUTE verbose level (-1) overrides home_config's BASIC (1)
      assert_equal false, result.verbose?(VerbosityLevel::BASIC), "Expected verbose?(BASIC) to be false due to suite_config override"
      assert_equal 2.5, result.test_warm_up, "Expected test_warm_up from setup config"
      assert_equal "asc", result.summary_order, "Expected summary_order from setup config"
      assert_equal true, result.quiet?, "Expected quiet from suite config (verbose set to MUTE)"
      assert_equal 5, result.test_time, "Expected test_time from current config"
    end

    def test_load_with_precedence_and_thor_options
      # Create config files in all locations
      home_config = {runtime: "both", verbose: VerbosityLevel::BASIC.value}
      setup_config = {test_warm_up: 2.5, summary_order: "asc"}
      suite_config = {runtime: "yjit", verbose: VerbosityLevel::MUTE.value}
      current_config = {test_time: 5}

      create_config_file(File.join(@home_dir, ".awfy.json"), home_config)
      create_config_file(File.join(@setup_dir, ".awfy.json"), setup_config)
      create_config_file(File.join(@suite_dir, ".awfy.json"), suite_config)
      create_config_file(File.join(Dir.pwd, ".awfy.json"), current_config)

      # Add thor options with some defaults and some explicit
      thor_options = {
        runtime: "mri",            # Thor default
        test_time: 3.0,            # Thor default
        storage_backend: "sqlite", # Thor default
        storage_name: "custom_db",  # User explicit option
        # Thor options also have verbose settings that could interact
        verbose: VerbosityLevel::NONE.value # Default Thor verbose if not specified by user
      }

      # Explicitly set options (would come from the user)
      # If user specified --verbose=1 (BASIC) on CLI, it would be in explicit_options
      # For this test, let's assume no explicit verbose CLI option, so explicit_options is empty for verbose.
      explicit_options = {storage_name: "custom_db"}

      # Create config loader with thor options
      config_loader = ConfigLoader.new(
        thor_options,
        explicit_options,
        tests_path: @suite_dir,
        setup_file_path: File.join(@setup_dir, "setup.rb")
      )

      # Load the merged config
      result = config_loader.load_with_precedence

      # Make sure the default thor option didn't override the config
      assert_equal "yjit", result.runtime, "Expected runtime from config file, got thor default"
      assert_equal 5, result.test_time, "Expected test_time from config file, got thor default"

      # Make sure explicit thor option did override the config
      assert_equal "custom_db", result.storage_name, "Expected storage_name from explicit thor option"

      # Other values should be preserved from config files
      # Suite config's MUTE verbose level (-1) overrides home_config's BASIC (1)
      # Thor options (NONE=0) are lower precedence than file configs. Explicit CLI options are highest.
      # Since suite_config (MUTE) is highest precedence among files for verbose, it should win.
      assert_equal false, result.verbose?(VerbosityLevel::BASIC), "Expected verbose?(BASIC) to be false due to suite_config override"
      assert_equal 2.5, result.test_warm_up, "Expected test_warm_up from setup config"
      assert_equal "asc", result.summary_order, "Expected summary_order from setup config"
      assert_equal true, result.quiet?, "Expected quiet from suite config (verbose set to MUTE)"
    end

    def test_path_for_setup
      expected_path = File.join(@setup_dir, ".awfy.json")
      actual_path = @config_loader.path_for(ConfigLocation::Setup)
      assert_equal expected_path, actual_path
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
