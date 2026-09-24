# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

module Awfy
  module Views
    class TestConfigView < ViewTestCase
      def test_initialize
        view = ConfigView.new(session: @session)

        assert_instance_of ConfigView, view
      end

      def test_inherits_from_base_view
        view = ConfigView.new(session: @session)

        assert_kind_of BaseView, view
      end

      def test_display_configuration_silent_when_not_verbose
        config = Config.new(
          verbose: VerbosityLevel::MUTE.value
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        view = ConfigView.new(session: session)
        view.display_configuration

        assert_empty shell.messages
      end

      def test_display_configuration_outputs_when_verbose
        config = Config.new(
          verbose: VerbosityLevel::BASIC.value,
          runtime: "mri"
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        view = ConfigView.new(session: session)
        view.display_configuration

        refute_empty shell.messages
      end

      def test_display_configuration_shows_branch_info
        config = Config.new(
          verbose: VerbosityLevel::BASIC.value
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        view = ConfigView.new(session: session)
        view.display_configuration

        messages_text = shell.messages.map { |m| m[:message] }.join("\n")
        assert_includes messages_text, "branch"
      end

      def test_display_configuration_shows_runtime
        config = Config.new(
          verbose: VerbosityLevel::BASIC.value,
          runtime: "yjit"
        )
        shell = TestShell.new(config: config)
        session = Session.new(
          shell: shell,
          config: config,
          git_client: @git_client,
          results_store: @results_store
        )

        view = ConfigView.new(session: session)
        view.display_configuration

        messages_text = shell.messages.map { |m| m[:message] }.join("\n")
        assert_includes messages_text, "Runtime"
      end

      def test_format_and_display_config_formats_hash
        view = ConfigView.new(session: @session)

        view.format_and_display_config({key1: "value1", key2: 42})

        messages = @shell.messages.map { |m| m[:message] }
        assert messages.any? { |m| m.include?("key1") }
        assert messages.any? { |m| m.include?("value1") }
        assert messages.any? { |m| m.include?("key2") }
        assert messages.any? { |m| m.include?("42") }
      end

      def test_format_config_value_symbol
        view = ConfigView.new(session: @session)

        formatted = view.send(:format_config_value, :test_symbol)

        assert_equal ":test_symbol\n", formatted
      end

      def test_format_config_value_hash
        view = ConfigView.new(session: @session)

        formatted = view.send(:format_config_value, {nested: "value"})

        assert_equal({nested: "value"}.inspect, formatted)
      end

      def test_format_config_value_array
        view = ConfigView.new(session: @session)

        formatted = view.send(:format_config_value, [1, 2, 3])

        assert_equal [1, 2, 3].inspect, formatted
      end

      def test_format_config_value_string
        view = ConfigView.new(session: @session)

        formatted = view.send(:format_config_value, "simple string")

        assert_equal "simple string\n", formatted
      end

      def test_format_config_value_integer
        view = ConfigView.new(session: @session)

        formatted = view.send(:format_config_value, 123)

        assert_equal "123\n", formatted
      end
    end
  end
end
