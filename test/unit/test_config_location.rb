# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestConfigLocation < Minitest::Test
    def test_home_location
      assert_equal "home", ConfigLocation::Home.value
      assert_instance_of ConfigLocation, ConfigLocation::Home
    end

    def test_setup_location
      assert_equal "setup", ConfigLocation::Setup.value
      assert_instance_of ConfigLocation, ConfigLocation::Setup
    end

    def test_suite_location
      assert_equal "suite", ConfigLocation::Suite.value
      assert_instance_of ConfigLocation, ConfigLocation::Suite
    end

    def test_current_location
      assert_equal "current", ConfigLocation::Current.value
      assert_instance_of ConfigLocation, ConfigLocation::Current
    end

    def test_all_locations
      locations = [
        ConfigLocation::Home,
        ConfigLocation::Setup,
        ConfigLocation::Suite,
        ConfigLocation::Current
      ]

      locations.each do |location|
        assert_instance_of ConfigLocation, location
        assert location.value.is_a?(String)
        assert location.value.length > 0
      end
    end

    def test_location_values_unique
      values = [
        ConfigLocation::Home.value,
        ConfigLocation::Setup.value,
        ConfigLocation::Suite.value,
        ConfigLocation::Current.value
      ]

      assert_equal values.uniq.size, values.size, "All location values should be unique"
    end

    def test_location_indexing
      assert_equal ConfigLocation::Home, ConfigLocation["home"]
      assert_equal ConfigLocation::Setup, ConfigLocation["setup"]
      assert_equal ConfigLocation::Suite, ConfigLocation["suite"]
      assert_equal ConfigLocation::Current, ConfigLocation["current"]
    end
  end
end
