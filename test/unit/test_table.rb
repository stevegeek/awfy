# frozen_string_literal: true

require_relative "views/test_helper"

module Awfy
  module Views
    class TestTable < ViewTestCase
      # TestTableClass is a dummy class for testing Table functionality
      class TestTableClass < Awfy::Views::Table
        def title
          "Test Table Title"
        end
      end

      def setup
        super

        # Sample results for testing
        @results = [
          Awfy::Views::Row.new(identifier: "1", columns: {col1: "A", col2: 1, col3: 2.5}),
          Awfy::Views::Row.new(identifier: "2", columns: {col1: "B", col2: 2, col3: 3.5}),
          Awfy::Views::Row.new(identifier: "3", columns: {col1: "C", col2: 3, col3: 4.5})
        ]

        # Instantiate TestTableClass with the session
        @table_view = TestTableClass.new(
          rows: @results,
          group_name: "Group",
          session: @session
        )
      end

      def test_title
        assert_equal "Test Table Title", @table_view.title
      end

      def test_table_theme
        refute @table_view.theme # default is nil
      end

      def test_rows
        assert_equal 3, @table_view.rows.size
        assert_equal "1", @table_view.rows[0].identifier
        assert_equal "A", @table_view.rows[0].columns[:col1]
        assert_equal 1, @table_view.rows[0].columns[:col2]
        assert_equal 2.5, @table_view.rows[0].columns[:col3]
      end
    end
  end
end
