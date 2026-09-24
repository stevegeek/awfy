# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestColorMode < Minitest::Test
    def test_auto_constant
      assert_equal "auto", ColorMode::AUTO.value
      assert_instance_of ColorMode, ColorMode::AUTO
    end

    def test_light_constant
      assert_equal "light", ColorMode::LIGHT.value
      assert_instance_of ColorMode, ColorMode::LIGHT
    end

    def test_dark_constant
      assert_equal "dark", ColorMode::DARK.value
      assert_instance_of ColorMode, ColorMode::DARK
    end

    def test_off_constant
      assert_equal "off", ColorMode::OFF.value
      assert_instance_of ColorMode, ColorMode::OFF
    end

    def test_ansi_constant
      assert_equal "ansi", ColorMode::ANSI.value
      assert_instance_of ColorMode, ColorMode::ANSI
    end

    def test_all_color_modes_have_unique_values
      values = [
        ColorMode::AUTO.value,
        ColorMode::LIGHT.value,
        ColorMode::DARK.value,
        ColorMode::OFF.value,
        ColorMode::ANSI.value
      ]
      assert_equal values.uniq.size, values.size
    end

    def test_can_index_by_string
      assert_equal ColorMode::AUTO, ColorMode["auto"]
      assert_equal ColorMode::LIGHT, ColorMode["light"]
      assert_equal ColorMode::DARK, ColorMode["dark"]
      assert_equal ColorMode::OFF, ColorMode["off"]
      assert_equal ColorMode::ANSI, ColorMode["ansi"]
    end

    def test_index_returns_nil_for_unknown_value
      assert_nil ColorMode["unknown"]
    end

    def test_color_modes_are_comparable
      assert_equal ColorMode::AUTO, ColorMode::AUTO
      refute_equal ColorMode::AUTO, ColorMode::LIGHT
    end

    def test_color_modes_can_be_used_in_case_statements
      result = case ColorMode::DARK
      when ColorMode::LIGHT
        "light"
      when ColorMode::DARK
        "dark"
      when ColorMode::AUTO
        "auto"
      else
        "other"
      end

      assert_equal "dark", result
    end

    def test_all_modes_are_strings
      [
        ColorMode::AUTO,
        ColorMode::LIGHT,
        ColorMode::DARK,
        ColorMode::OFF,
        ColorMode::ANSI
      ].each do |mode|
        assert_instance_of String, mode.value
      end
    end
  end
end
