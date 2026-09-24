# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestShellClass < Minitest::Test
    def create_config(color: ColorMode::OFF)
      Config.new(
        verbose: VerbosityLevel::MUTE,
        color: color
      )
    end

    def test_initialize
      config = create_config
      shell = Shell.new(config: config)

      assert_instance_of Shell, shell
    end

    def test_unicode_symbols_defined
      assert_kind_of Hash, Shell::UNICODE_SYMBOLS
      assert Shell::UNICODE_SYMBOLS.key?(:up)
      assert Shell::UNICODE_SYMBOLS.key?(:down)
      assert Shell::UNICODE_SYMBOLS.key?(:check)
      assert Shell::UNICODE_SYMBOLS.key?(:cross)
    end

    def test_ascii_symbols_defined
      assert_kind_of Hash, Shell::ASCII_SYMBOLS
      assert Shell::ASCII_SYMBOLS.key?(:up)
      assert Shell::ASCII_SYMBOLS.key?(:down)
      assert Shell::ASCII_SYMBOLS.key?(:check)
      assert Shell::ASCII_SYMBOLS.key?(:cross)
    end

    def test_symbols_returns_hash
      config = create_config
      shell = Shell.new(config: config)

      symbols = shell.symbols

      assert_kind_of Hash, symbols
      assert symbols.key?(:up)
    end

    def test_terminal_info_returns_shell_info
      config = create_config
      shell = Shell.new(config: config)

      info = shell.terminal_info

      assert_instance_of ShellInfo, info
    end

    def test_terminal_info_is_cached
      config = create_config
      shell = Shell.new(config: config)

      info1 = shell.terminal_info
      info2 = shell.terminal_info

      assert_same info1, info2
    end

    def test_unicode_supported_returns_boolean
      config = create_config
      shell = Shell.new(config: config)

      result = shell.unicode_supported?

      assert [true, false].include?(result)
    end

    def test_color_supported_returns_false_when_color_off
      config = create_config(color: ColorMode::OFF)
      shell = Shell.new(config: config)

      refute shell.color_supported?
    end

    def test_respond_to_missing_for_thor_methods
      config = create_config
      shell = Shell.new(config: config)

      assert shell.respond_to?(:say)
    end

    def test_method_missing_delegates_to_thor_shell
      config = create_config
      shell = Shell.new(config: config)

      # This should not raise - it delegates to Thor shell
      shell.say("test message")
    end

    def test_say_error_works
      config = create_config
      shell = Shell.new(config: config)

      # Capture stderr to verify say_error works
      original_stderr = $stderr
      $stderr = StringIO.new

      shell.say_error("Error message")

      output = $stderr.string
      $stderr = original_stderr

      # Thor's say_error should have been called
      assert_includes output, "Error message"
    end

    def test_symbols_consistency
      # Both symbol sets should have the same keys
      unicode_keys = Shell::UNICODE_SYMBOLS.keys.sort
      ascii_keys = Shell::ASCII_SYMBOLS.keys.sort

      assert_equal unicode_keys, ascii_keys
    end

    def test_all_symbol_values_are_strings
      Shell::UNICODE_SYMBOLS.each do |key, value|
        assert_kind_of String, value, "UNICODE_SYMBOLS[:#{key}] should be a String"
      end

      Shell::ASCII_SYMBOLS.each do |key, value|
        assert_kind_of String, value, "ASCII_SYMBOLS[:#{key}] should be a String"
      end
    end
  end
end
