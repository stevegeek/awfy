# frozen_string_literal: true

require "table_tennis"

module Awfy
  module Views
    # Common table formatting methods shared across view classes
    module TableFormatter
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
        results_by_commit[commit][runtime].find { |r| r[:label] == test_label }
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

      # Format a table with enhanced styling using table_tennis
      def format_table(title, headings, rows, options = {})
        max_values = options.delete(:max_values) || {}
        baseline_index = nil

        raise "WHAT" unless IO.console

        # Process rows to add performance bars and format comparisons
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
            if row[4] == "-"
              baseline_index = i
              enhanced_row[4] = format_comparison_modern(row[4], true)
            else
              enhanced_row[4] = format_comparison_modern(row[4], false)
            end
          end

          # Color the runtime field
          if row[1] && headings[1] == "Runtime"
            enhanced_row[1] = color_text(row[1], (row[1] == "yjit") ? :magenta : :cyan)
          end

          enhanced_row
        end

        # Set options for table_tennis
        theme = if config.color_ansi?
          :ansi
        elsif !config.color_enabled?
          :light
        elsif config.color == ColorMode::AUTO
          :dark # Default to dark when auto is selected
        else
          config.color.value.to_sym
        end

        table_options = {
          title: title,
          theme: theme,
          zebra: true,
          separators: true
        }

        # Mark baseline row if found
        if baseline_index
          table_options[:mark] = {rows: [baseline_index]}
        end

        # Merge with any additional options
        table_options.merge!(options)

        # Use the TableFormatter's implementation which now uses table_tennis
        # Don't call super since there's no superclass method
        # Instead call format_table directly
        header_keys = headings.map { |h| h.to_s.downcase.gsub(/\s+/, "_").to_sym }
        rows_data = enhanced_rows.map do |row|
          header_keys.zip(row).to_h
        end

        # Create table instance - always use TableTennis for consistent output
        TableTennis.new(rows_data, **table_options).to_s
      end

      private

      def color_text(text, color)
        return text if color.nil? || !config.color_enabled?
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
