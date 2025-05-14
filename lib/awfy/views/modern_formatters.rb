# frozen_string_literal: true

module Awfy
  module Views
    # Modern formatting helpers for prettier output
    module ModernFormatters
      # Unicode symbols for visual indicators
      UNICODE_SYMBOLS = {
        up: "▲",
        down: "▼",
        neutral: "•",
        bar_full: "█",
        bar_empty: "░",
        check: "✓",
        cross: "✗",
        baseline: "○"
      }.freeze

      # ASCII fallbacks for terminals that don't support Unicode
      ASCII_SYMBOLS = {
        up: "^",
        down: "v",
        neutral: "*",
        bar_full: "#",
        bar_empty: "-",
        check: "+",
        cross: "x",
        baseline: "o"
      }.freeze

      # Color codes
      COLORS = {
        green: :green,
        yellow: :yellow,
        red: :red,
        cyan: :cyan,
        magenta: :magenta,
        default: nil
      }.freeze

      def use_modern_style?
        !config.classic_style?
      end

      # Get appropriate symbols based on terminal capabilities
      def symbols
        unicode_supported? ? UNICODE_SYMBOLS : ASCII_SYMBOLS
      end

      # Format a comparison value with color and trend indicators
      def format_comparison_modern(value, is_baseline = false)
        return "#{symbols[:baseline]} baseline" if is_baseline

        if value == "same"
          return "#{symbols[:neutral]} same"
        elsif value == "∞"
          return color_text("#{symbols[:up]} ∞ x", COLORS[:green])
        end

        # Extract numeric value from "X.XX x" format
        numeric_value = value.to_s.gsub(/ x$/, "").to_f

        if numeric_value > 1.0
          color_text("#{symbols[:up]} #{numeric_value.round(2)} x", COLORS[:green])
        elsif numeric_value < 1.0
          color_text("#{symbols[:down]} #{numeric_value.round(2)} x", COLORS[:red])
        else
          "#{symbols[:neutral]} #{numeric_value.round(2)} x"
        end
      end

      # Create a visual performance bar relative to best result
      def performance_bar(value, max_value, width = 10)
        return "" if max_value.nil? || max_value.zero?

        # For terminals that don't support graphics well, use a shorter bar
        width = unicode_supported? ? width : [width, 5].min

        ratio = [value.to_f / max_value.to_f, 1.0].min
        filled = (ratio * width).round
        empty = width - filled

        bar = symbols[:bar_full] * filled + symbols[:bar_empty] * empty
        color = if ratio > 0.8
          COLORS[:green]
        else
          ((ratio > 0.4) ? COLORS[:yellow] : COLORS[:red])
        end

        color_text(bar, color)
      end

      def format_table(title, headings, rows)
        return format_modern_table(title, headings, rows) if use_modern_style?
        super
      end

      # Format a table with enhanced styling
      def format_modern_table(title, headings, rows, max_values = {})
        # Enhance the table title with color if supported
        enhanced_title = color_supported? ? Rainbow(title).bright : title

        # Enhance headings with color if supported
        enhanced_headings = color_supported? ?
          headings.map { |h| Rainbow(h).bright } :
          headings

        # Create the table
        table = ::Terminal::Table.new(
          title: enhanced_title,
          headings: enhanced_headings
        )

        # Use unicode border style if supported
        if unicode_supported?
          begin
            table.style = {border: :unicode}
          rescue NoMethodError
            # Fallback to default border style if method not available
          end
        end

        # Enhanced rows with visual indicators
        enhanced_rows = rows.map.with_index do |row, i|
          enhanced_row = row.dup

          # Add performance bar for IPS column if present
          if row[3] && headings[3] == "IPS" && max_values[:ips]
            ips_value = extract_numeric_value(row[3])
            bar = performance_bar(ips_value, max_values[:ips])
            enhanced_row[3] = "#{row[3]} #{bar}"
          end

          # Format comparison column if present
          if row[4] && headings[4] == "Vs baseline"
            enhanced_row[4] = format_comparison_modern(row[4], row[4] == "-")
          end

          # Color the runtime field
          if row[1] && headings[1] == "Runtime"
            enhanced_row[1] = color_text(row[1], (row[1] == "yjit") ? :magenta : :cyan)
          end

          # Highlight the baseline row
          if row[4] == "-" && headings[4] == "Vs baseline"
            enhanced_row[2] = Rainbow(row[2]).bright
          end

          enhanced_row
        end

        # Add rows to the table
        enhanced_rows.each do |row|
          table.add_row(row)
          # Add a separator after the baseline row
          if row[4] == "-" && headings[4] == "Vs baseline"
            table.add_separator
          end
        end

        # Right-align numeric columns
        (1...headings.size).each do |i|
          if rows.all? { |row| row[i].is_a?(Numeric) || (row[i].is_a?(String) && (row[i] =~ /^\s*-?\d+(\.\d+)?/) || row[i] == "-") }
            table.align_column(i, :right)
          end
        end

        table
      end

      private

      def color_text(text, color)
        return text if color.nil? || !color_supported?
        Rainbow(text).color(color)
      end

      def extract_numeric_value(formatted_value)
        if formatted_value.is_a?(String) && formatted_value =~ /([0-9.]+)([kMBTQ])?/
          value = $1.to_f
          suffix = $2 || ""

          multiplier = case suffix
          when "k" then 1_000
          when "M" then 1_000_000
          when "B" then 1_000_000_000
          when "T" then 1_000_000_000_000
          when "Q" then 1_000_000_000_000_000
          else 1
          end

          value * multiplier
        else
          formatted_value.to_f
        end
      end
    end
  end
end
