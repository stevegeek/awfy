# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestHasSession < Minitest::Test
    # Test class that includes HasSession
    class TestClass
      extend Literal::Properties
      include Awfy::HasSession
    end

    def setup
      # Create a config for the shell
      @config = Awfy::Config.new(verbose: true)

      # Create a proper Shell instance
      @shell = Awfy::Shell.new(config: @config)

      # Add test-specific methods to track messages
      @shell.instance_variable_set(:@last_message, nil)
      @shell.instance_variable_set(:@last_error, nil)

      class << @shell
        attr_accessor :last_message, :last_error

        def say(*args)
          @last_message = args.first
          super
        end

        def say_error(*args)
          @last_error = args.first
          super
        end
      end

      # Create a real GitClient for type safety
      @git_client = Awfy::GitClient.new(path: Dir.pwd)

      # Create a results store
      @results_store = Awfy::Stores::Memory.new(storage_name: "memory", retention_policy: Awfy::RetentionPolicies::KeepAll.new)

      # Create session instance
      @session = Awfy::Session.new(
        shell: @shell,
        config: @config,
        git_client: @git_client,
        results_store: @results_store
      )

      # Create test object that includes HasSession
      @test_object = TestClass.new(session: @session)
    end

    def test_git_client_delegation
      assert_equal @git_client, @test_object.git_client
    end

    def test_config_delegation
      assert_equal @config, @test_object.config
    end

    def test_say_delegation
      test_message = "Test message"
      @test_object.say(test_message)
      assert_equal test_message, @shell.instance_variable_get(:@last_message)
    end

    def test_say_error_delegation
      test_error = "Test error"
      @test_object.say_error(test_error)
      assert_equal test_error, @shell.instance_variable_get(:@last_error)
    end

    def test_verbose_delegation
      assert_equal true, @test_object.verbose?

      # Test with a different config
      non_verbose_config = Awfy::Config.new(verbose: false)
      non_verbose_session = Awfy::Session.new(
        shell: @shell,
        config: non_verbose_config,
        git_client: @git_client,
        results_store: @results_store
      )
      non_verbose_test_object = TestClass.new(session: non_verbose_session)
      assert_equal false, non_verbose_test_object.verbose?
    end
  end
end
