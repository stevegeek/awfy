# frozen_string_literal: true

require "terminal-table"

module Awfy
  module Views
    # Base class for all views that handle output formatting
    class BaseView
      def initialize(shell, options)
        @shell = shell
        @options = options
      end
      
      # Say something to the shell
      def say(message = "", color = nil)
        @shell.say(message, color)
      end
      
      # Say an error message
      def say_error(message)
        @shell.say_error(message)
      end
      
      # Check if we're in verbose mode
      def verbose?
        @options.verbose?
      end
      
      # Check if summary should be shown
      def show_summary?
        @options.show_summary?
      end
      
      # Format a table with consistent styling
      # @param title [String] Table title
      # @param headings [Array<String>] Column headings
      # @param rows [Array<Array>] Table data rows
      # @return [String] The formatted table
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
      
      # Format a number with appropriate scale (K, M, B, etc.)
      # @param number [Integer] The number to format
      # @param round_to [Integer] Number of decimal places
      # @return [String] Formatted number
      def humanize_scale(number, round_to: 0)
        suffixes = ["", "k", "M", "B", "T", "Q"]
        
        return "0" if number.zero?
        number = number.round(round_to)
        scale = (Math.log10(number) / 3).to_i
        scale = 0 if scale < 0 || scale >= suffixes.size
        suffix = suffixes[scale]
        scaled_value = number.to_f / (1000**scale)
        dp = (scale == 0) ? 0 : 3
        "%10.#{dp}f#{suffix}" % scaled_value
      end
      
      # Format a percentage change
      # @param ratio [Float] The ratio (1.0 = no change)
      # @return [String] Formatted percentage
      def format_change(ratio)
        if ratio > 1.0
          "+#{((ratio - 1) * 100).round(1)}%"
        elsif ratio < 1.0
          "-#{((1 - ratio) * 100).round(1)}%"
        else
          "No change"
        end
      end
      
      # Format a comparison result
      # @param ratio [Float] The comparison ratio
      # @param higher_is_better [Boolean] Whether higher values are better
      # @return [String] Formatted comparison
      def format_comparison(ratio, higher_is_better = true)
        return "baseline" if ratio == 1.0
        
        if higher_is_better
          if ratio > 1.0
            "#{ratio.round(2)}x faster"
          else
            "#{(1.0 / ratio).round(2)}x slower"
          end
        else
          if ratio < 1.0
            "#{(1.0 / ratio).round(2)}x better"
          else
            "#{ratio.round(2)}x worse"
          end
        end
      end
    end
  end
end