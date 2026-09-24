# frozen_string_literal: true

require "test_helper"

module Awfy
  module Views
    class TestRow < Minitest::Test
      def test_initialize_with_required_attributes
        row = Row.new(
          identifier: "row-1",
          columns: {name: "Test", value: 100}
        )

        assert_equal "row-1", row.identifier
        assert_equal({name: "Test", value: 100}, row.columns)
        refute row.highlight?
      end

      def test_initialize_with_highlight_true
        row = Row.new(
          identifier: "row-2",
          columns: {name: "Highlighted"},
          highlight: true
        )

        assert row.highlight?
      end

      def test_initialize_with_highlight_false
        row = Row.new(
          identifier: "row-3",
          columns: {name: "Not Highlighted"},
          highlight: false
        )

        refute row.highlight?
      end

      def test_highlight_defaults_to_false
        row = Row.new(
          identifier: "row-4",
          columns: {}
        )

        refute row.highlight?
      end

      def test_columns_can_be_hash_with_various_types
        row = Row.new(
          identifier: "row-5",
          columns: {
            string: "text",
            number: 42,
            float: 3.14,
            symbol: :value,
            array: [1, 2, 3],
            nested: {key: "value"}
          }
        )

        assert_equal "text", row.columns[:string]
        assert_equal 42, row.columns[:number]
        assert_equal 3.14, row.columns[:float]
        assert_equal :value, row.columns[:symbol]
        assert_equal [1, 2, 3], row.columns[:array]
        assert_equal({key: "value"}, row.columns[:nested])
      end

      def test_columns_can_be_empty_hash
        row = Row.new(
          identifier: "row-6",
          columns: {}
        )

        assert_equal({}, row.columns)
        assert_empty row.columns
      end

      def test_to_h_returns_columns
        columns = {col1: "value1", col2: "value2"}
        row = Row.new(
          identifier: "row-7",
          columns: columns
        )

        assert_equal columns, row.to_h
      end

      def test_identifier_must_be_string
        row = Row.new(
          identifier: "my-id",
          columns: {}
        )

        assert_instance_of String, row.identifier
      end

      def test_multiple_rows_with_different_identifiers
        row1 = Row.new(identifier: "row-1", columns: {value: 1})
        row2 = Row.new(identifier: "row-2", columns: {value: 2})
        row3 = Row.new(identifier: "row-3", columns: {value: 3})

        refute_equal row1.identifier, row2.identifier
        refute_equal row2.identifier, row3.identifier
        refute_equal row1.identifier, row3.identifier
      end

      def test_rows_with_same_identifier_are_equal
        row1 = Row.new(identifier: "same", columns: {a: 1}, highlight: false)
        row2 = Row.new(identifier: "same", columns: {a: 1}, highlight: false)

        assert_equal row1, row2
      end

      def test_rows_with_different_highlight_are_not_equal
        row1 = Row.new(identifier: "same", columns: {a: 1}, highlight: false)
        row2 = Row.new(identifier: "same", columns: {a: 1}, highlight: true)

        refute_equal row1, row2
      end

      def test_columns_access_with_symbol_keys
        row = Row.new(
          identifier: "test",
          columns: {name: "Test Name", score: 95}
        )

        assert_equal "Test Name", row.columns[:name]
        assert_equal 95, row.columns[:score]
      end

      def test_columns_can_contain_nil_values
        row = Row.new(
          identifier: "test",
          columns: {present: "value", absent: nil}
        )

        assert_equal "value", row.columns[:present]
        assert_nil row.columns[:absent]
        assert row.columns.key?(:absent)
      end
    end
  end
end
