# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestSession < Minitest::Test
    def setup
      # Create a test shell with required interface methods
      @shell = Object.new
      def @shell.ask(*args); end
      def @shell.say(*args); @last_message = args.first; end
      def @shell.say_error(*args); @last_error = args.first; end
      def @shell.say_status(*args); end
      def @shell.mute(*args); end
      def @shell.mute?(*args); end

      # Create config
      @config = Awfy::Config.new(verbose: true)
      
      # Create a real GitClient for type safety
      @git_client = Awfy::GitClient.new(path: Dir.pwd)
      
      # Create session instance
      @session = Awfy::Session.new(
        shell: @shell,
        config: @config,
        git_client: @git_client
      )
    end

    def test_initialization
      assert_equal @shell, @session.shell
      assert_equal @config, @session.config
      assert_equal @git_client, @session.git_client
    end

    def test_say_method
      test_message = "Test message"
      @session.say(test_message)
      assert_equal test_message, @shell.instance_variable_get(:@last_message)
    end

    def test_say_error_method
      test_error = "Test error"
      @session.say_error(test_error)
      assert_equal test_error, @shell.instance_variable_get(:@last_error)
    end

    def test_verbose_predicate
      assert_equal true, @session.verbose?
      
      # Test with a different config
      non_verbose_config = Awfy::Config.new(verbose: false)
      non_verbose_session = Awfy::Session.new(
        shell: @shell,
        config: non_verbose_config,
        git_client: @git_client
      )
      assert_equal false, non_verbose_session.verbose?
    end
  end
end