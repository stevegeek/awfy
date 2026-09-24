# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestRuntimes < Minitest::Test
    def test_mri_constant
      assert_equal "mri", Runtimes::MRI.value
      assert_instance_of Runtimes, Runtimes::MRI
    end

    def test_yjit_constant
      assert_equal "yjit", Runtimes::YJIT.value
      assert_instance_of Runtimes, Runtimes::YJIT
    end

    def test_name_returns_uppercase
      assert_equal "MRI", Runtimes::MRI.name
      assert_equal "YJIT", Runtimes::YJIT.name
    end

    def test_all_runtimes_have_unique_values
      values = [Runtimes::MRI.value, Runtimes::YJIT.value]
      assert_equal values.uniq.size, values.size
    end

    def test_can_index_by_string
      assert_equal Runtimes::MRI, Runtimes["mri"]
      assert_equal Runtimes::YJIT, Runtimes["yjit"]
    end

    def test_index_returns_nil_for_unknown_value
      assert_nil Runtimes["unknown"]
    end

    def test_runtimes_are_comparable
      assert_equal Runtimes::MRI, Runtimes::MRI
      refute_equal Runtimes::MRI, Runtimes::YJIT
    end

    def test_runtimes_can_be_used_in_case_statements
      result = case Runtimes::MRI
      when Runtimes::MRI
        "mri_case"
      when Runtimes::YJIT
        "yjit_case"
      end

      assert_equal "mri_case", result
    end

    def test_value_returns_string
      assert_instance_of String, Runtimes::MRI.value
      assert_instance_of String, Runtimes::YJIT.value
    end

    def test_name_method_preserves_case
      # name() returns uppercase version
      assert_match(/^[A-Z]+$/, Runtimes::MRI.name)
      assert_match(/^[A-Z]+$/, Runtimes::YJIT.name)
    end
  end
end
