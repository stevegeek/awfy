# frozen_string_literal: true

require "test_helper"
require "stringio"
require "awfy/config"

module Awfy
  class TestVerbosityLevel < Minitest::Test
    def test_verbosity_level_enum_values
      assert_equal 0, Awfy::VerbosityLevel::NONE.value
      assert_equal 1, Awfy::VerbosityLevel::BASIC.value
      assert_equal 2, Awfy::VerbosityLevel::DETAILED.value
      assert_equal 3, Awfy::VerbosityLevel::DEBUG.value
    end

    def test_config_with_verbosity_level
      # Test with none
      config = Awfy::Config.new(verbose: Awfy::VerbosityLevel::NONE)
      assert_equal Awfy::VerbosityLevel::NONE, config.verbose
      refute config.verbose?, "verbose? should be false with NONE level"
      refute config.verbose?(Awfy::VerbosityLevel::BASIC), "verbose?(BASIC) should be false with NONE level"

      # Test with basic
      config = Awfy::Config.new(verbose: Awfy::VerbosityLevel::BASIC)
      assert_equal Awfy::VerbosityLevel::BASIC, config.verbose
      assert config.verbose?, "verbose? should be true with BASIC level"
      assert config.verbose?(Awfy::VerbosityLevel::BASIC), "verbose?(BASIC) should be true with BASIC level"
      refute config.verbose?(Awfy::VerbosityLevel::DETAILED), "verbose?(DETAILED) should be false with BASIC level"

      # Test with detailed
      config = Awfy::Config.new(verbose: Awfy::VerbosityLevel::DETAILED)
      assert_equal Awfy::VerbosityLevel::DETAILED, config.verbose
      assert config.verbose?, "verbose? should be true with DETAILED level"
      assert config.verbose?(Awfy::VerbosityLevel::BASIC), "verbose?(BASIC) should be true with DETAILED level"
      assert config.verbose?(Awfy::VerbosityLevel::DETAILED), "verbose?(DETAILED) should be true with DETAILED level"
      refute config.verbose?(Awfy::VerbosityLevel::DEBUG), "verbose?(DEBUG) should be false with DETAILED level"

      # Test with debug
      config = Awfy::Config.new(verbose: Awfy::VerbosityLevel::DEBUG)
      assert_equal Awfy::VerbosityLevel::DEBUG, config.verbose
      assert config.verbose?, "verbose? should be true with DEBUG level"
      assert config.verbose?(Awfy::VerbosityLevel::BASIC), "verbose?(BASIC) should be true with DEBUG level"
      assert config.verbose?(Awfy::VerbosityLevel::DETAILED), "verbose?(DETAILED) should be true with DEBUG level"
      assert config.verbose?(Awfy::VerbosityLevel::DEBUG), "verbose?(DEBUG) should be true with DEBUG level"
    end

    def test_config_with_numeric_verbosity
      # Test with integer values that should be converted to VerbosityLevel
      config = Awfy::Config.new(verbose: 0)
      assert_equal Awfy::VerbosityLevel::NONE, config.verbose

      config = Awfy::Config.new(verbose: 1)
      assert_equal Awfy::VerbosityLevel::BASIC, config.verbose

      config = Awfy::Config.new(verbose: 2)
      assert_equal Awfy::VerbosityLevel::DETAILED, config.verbose

      config = Awfy::Config.new(verbose: 3)
      assert_equal Awfy::VerbosityLevel::DEBUG, config.verbose
    end
  end
end
