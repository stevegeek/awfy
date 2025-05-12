# frozen_string_literal: true

require "terminal-table"

module Awfy
  module Views
    # Common table formatting methods shared across view classes
    module TableFormatter
      def format_table(title, headings, rows)
        table = ::Terminal::Table.new(title: title, headings: headings)

        rows.each do |row|
          table.add_row(row)
        end

        # Right-align numeric columns (2nd column and beyond)
        (1...headings.size).each do |i|
          # Only right-align if all values in column are numeric
          if rows.all? { |row| row[i].is_a?(Numeric) || (row[i].is_a?(String) && (row[i] =~ /^\s*-?\d+(\.\d+)?/) || row[i] == "-") }
            table.align_column(i, :right)
          end
        end

        table
      end

      def table_title(group, report = nil, test = nil)
        tests = [group, report, test].compact
        return "Run: (all)" if tests.empty?
        "Run: #{tests.join("/")}"
      end

      def order_description(is_memory = false)
        case config.summary_order
        when "asc"
          is_memory ? "Results displayed in ascending order (lowest memory first)" : "Results displayed in ascending order"
        when "desc"
          is_memory ? "Results displayed in descending order (highest memory first)" : "Results displayed in descending order"
        else # Default to "leader"
          "Results displayed as a leaderboard (best to worst)"
        end
      end

      def sort_results(results, value_extractor, invert = false)
        results.sort_by do |result|
          factor = (config.summary_order == "asc") ? 1 : -1
          factor *= -1 if invert
          factor * value_extractor.call(result)
        end
      end

      def has_runtime?(results_by_commit, runtime)
        results_by_commit.any? { |_, data| data[runtime] }
      end

      def find_test_result(results_by_commit, commit, runtime, test_label)
        return nil unless results_by_commit[commit] && results_by_commit[commit][runtime]
        results_by_commit[commit][runtime].find { |r| r[:item] == test_label }
      end
    end
  end
end
