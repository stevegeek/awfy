# frozen_string_literal: true

require "terminal-table"

module Awfy
  module Views
    # Base class for all views that handle output formatting
    class BaseView
      include TableFormatter
      include ComparisonFormatters

      def initialize(shell, options)
        @shell = shell
        @options = options
      end

      def say(message = "", color = nil)
        @shell.say(message, color)
      end

      def say_error(message)
        @shell.say_error(message)
      end

      def verbose?
        @options.verbose?
      end

      def show_summary?
        @options.show_summary?
      end

      def format_table(title, headings, rows)
        table = ::Terminal::Table.new(title: title, headings: headings)

        rows.each do |row|
          table.add_row(row)
        end

        # Right-align numeric columns (2nd column and beyond)
        (1...headings.size).each do |i|
          # Only right-align if all values in column are numeric
          if rows.all? { |row| row[i].is_a?(Numeric) || (row[i].is_a?(String) && row[i] =~ /^-?\d+(\.\d+)?/) }
            table.align_column(i, :right)
          end
        end

        table
      end
    end
  end
end
