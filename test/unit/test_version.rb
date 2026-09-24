# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestVersion < Minitest::Test
    def test_version_constant_exists
      assert defined?(Awfy::VERSION)
    end

    def test_version_is_a_string
      assert_instance_of String, VERSION
    end

    def test_version_has_expected_format
      # Version should be in format like "1.0.0" or "1.0.0.alpha1"
      assert_match(/^\d+\.\d+\.\d+/, VERSION)
    end

    def test_version_value
      # Just verify it's set to something reasonable
      refute_empty VERSION
      assert VERSION.length > 0
    end

    def test_version_can_be_split_into_parts
      # Should have at least major.minor.patch
      parts = VERSION.split(".")
      assert parts.length >= 3, "Version should have at least major.minor.patch"
    end

    def test_version_major_is_numeric
      major = VERSION.split(".").first
      assert_match(/^\d+$/, major)
    end

    def test_version_accessible_from_module
      # Can access as Awfy::VERSION
      assert_equal Awfy::VERSION, VERSION
    end
  end
end
