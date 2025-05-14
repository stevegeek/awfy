# frozen_string_literal: true

require "test_helper"
require "stringio"

module Awfy
  module Commands
    class TestConfig < Minitest::Test
      def setup
        @temp_dir = Dir.mktmpdir
        @home_dir = File.join(@temp_dir, "home")
        @suite_dir = File.join(@temp_dir, "benchmarks")
        @current_dir = File.join(@temp_dir, "current")

        # Create directory structure
        FileUtils.mkdir_p(@home_dir)
        FileUtils.mkdir_p(@suite_dir)
        FileUtils.mkdir_p(@current_dir)

        # Store original home directory and current directory
        @original_home = ENV["HOME"]
        @original_pwd = Dir.pwd
        ENV["HOME"] = @home_dir
        Dir.chdir(@current_dir)

        # Create real objects
        @config = Awfy::Config.new(test_time: 5, runtime: "both", verbose: VerbosityLevel::BASIC)
        @shell = Awfy::Shell.new(config: @config)
        # Use a mock git client to avoid Git repository requirements
        @git_client = GitClient.new(path: @original_pwd) # Use the actual repo we're in
        @results_store = Stores::Memory.new(storage_name: "test", retention_policy: RetentionPolicies::KeepAll.new)

        # Create session
        @session = Awfy::Session.new(
          shell: @shell,
          config: @config,
          git_client: @git_client,
          results_store: @results_store
        )

        # Create command
        @command = Awfy::Commands::Config.new(session: @session)
      end

      def teardown
        # Restore original directories
        ENV["HOME"] = @original_home
        Dir.chdir(@original_pwd)

        # Clean up temp directories
        FileUtils.remove_entry @temp_dir
      end

      def test_inspect_with_no_config_files
        # Use our own StringIO for output capture
        out = StringIO.new
        $stdout = out

        @command.inspect("home")

        # Restore normal stdout
        $stdout = STDOUT

        output = out.string
        assert_match(/No configuration file found/, output)
        assert_match(/If saved, would create with these settings/, output)
        assert_match(/test_time/, output)
        assert_match(/runtime/, output)
      end

      def test_save_and_inspect_config
        # Use our own StringIO for output capture
        out = StringIO.new
        $stdout = out

        # First save the config
        @command.save("home")

        # Capture output
        save_output = out.string
        assert_match(/Configuration saved to:.*\.awfy\.json/, save_output)

        # Clear output and inspect
        out.truncate(0)
        out.rewind

        # Then inspect it
        @command.inspect("home")

        # Restore normal stdout
        $stdout = STDOUT

        # Check output
        inspect_output = out.string
        assert_match(/Configuration at/, inspect_output)
        assert_match(/test_time.*5/, inspect_output)
        assert_match(/runtime.*both/, inspect_output)
        assert_match(/verbose.*basic/i, inspect_output)
      end

      def test_save_and_load_with_precedence
        # Use simple hashes directly instead of Config objects
        home_config = {runtime: "yjit", test_time: 10}
        suite_config = {runtime: "mri", verbose: Awfy::VerbosityLevel::NONE}
        current_config = {test_warm_up: 2}

        # Create the config loader
        config_loader = ConfigLoader.new(tests_path: @suite_dir)

        # Save configs at different locations
        config_loader.save(home_config, ConfigLocation::Home)
        config_loader.save(suite_config, ConfigLocation::Suite)
        config_loader.save(current_config, ConfigLocation::Current)

        # Load with precedence
        merged_config = config_loader.load_with_precedence

        # Highest precedence (current) should override others
        assert_equal 2, merged_config[:test_warm_up]
        assert_equal "mri", merged_config[:runtime], "Suite config should override home config"
        assert_equal VerbosityLevel::NONE, merged_config[:verbose], "Suite config should override home config"

        # Now modify current config and verify it takes precedence
        config_loader.save({runtime: "both"}, ConfigLocation::Current)
        merged_config = config_loader.load_with_precedence
        assert_equal "both", merged_config[:runtime], "Current config should override suite config"
      end
    end
  end
end
