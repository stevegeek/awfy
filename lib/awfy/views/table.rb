# frozen_string_literal: true

module Awfy
  module Views
    class Table < Literal::Object
      include HasSession

      prop :group_name, String, reader: :private
      prop :report_name, _Nilable(String), reader: :private
      prop :test_name, _Nilable(String), reader: :private

      prop :rows, _Array(Row), reader: :public

      def title
        tests = [group_name, report_name, test_name].compact
        return "Run: (all)" if tests.empty?

        "Run: #{tests.join("/")}"
      end

      def order_description
        case config.summary_order
        when "asc"
          "Results displayed in ascending order"
        when "desc"
          "Results displayed in descending order"
        else # Default to "leader"
          "Results displayed as a leaderboard (best to worst)"
        end
      end

      def theme
        case config.color
        when ColorMode::DARK
          :dark
        when ColorMode::LIGHT
          :light
        when ColorMode::ANSI
          :ansi
        else
          nil
        end
      end

      def headers
        # Default is to work out implicitly
      end

      def columns
        # Default is to render all columns
      end

      def mark
        # Mark the baseline is the default
        -> { it.highlight? }
      end

      def color_scales
        # no scales by default
      end
    end
  end
end
# exposes the title and settings, and row class instances

#
# max_values = options.delete(:max_values) || {}
#
# raise "WHAT" unless IO.console

# Process rows to add performance bars and format comparisons
# enhanced_rows = rows.map do |row|
#   enhanced_row = row.dup
#
# # Add performance bar for IPS column if present
# if row[3] && headings[3] == "IPS" && max_values[:ips]
#   ips_value = extract_numeric_value(row[3])
#   bar = performance_bar(ips_value, max_values[:ips])
#   enhanced_row[3] = "#{row[3]} #{bar}"
# end
#
# # Format comparison column if present
# if row[4] && headings[4] == "Vs baseline"
#   if row[4] == "-"
#     baseline_index = i
#     enhanced_row[4] = format_comparison_modern(row[4], true)
#   else
#     enhanced_row[4] = format_comparison_modern(row[4], false)
#   end
# end
#
# # Color the runtime field
# if row[1] && headings[1] == "Runtime"
#   enhanced_row[1] = color_text(row[1], (row[1] == "yjit") ? :magenta : :cyan)
# end
#
#   enhanced_row
# end



# Format a comparison value with color and trend indicators
# def format_comparison_modern(value, is_baseline = false)
#   return "#{symbols[:baseline]} baseline" if is_baseline
#
#   if value == "same"
#     return "#{symbols[:neutral]} same"
#   elsif value == "∞"
#     return color_text("#{symbols[:up]} ∞ x", COLORS[:green])
#   end
#
#   # Extract numeric value from "X.XX x" format
#   numeric_value = value.to_s.gsub(/ x$/, "").to_f
#
#   if numeric_value > 1.0
#     color_text("#{symbols[:up]} #{numeric_value.round(2)} x", COLORS[:green])
#   elsif numeric_value < 1.0
#     color_text("#{symbols[:down]} #{numeric_value.round(2)} x", COLORS[:red])
#   else
#     "#{symbols[:neutral]} #{numeric_value.round(2)} x"
#   end
# end
#
# # Create a visual performance bar relative to best result
# def performance_bar(value, max_value, width = 10)
#   return "" if max_value.nil? || max_value.zero?
#
#   # For terminals that don't support graphics well, use a shorter bar
#   width = unicode_supported? ? width : [width, 5].min
#
#   ratio = [value.to_f / max_value.to_f, 1.0].min
#   filled = (ratio * width).round
#   empty = width - filled
#
#   bar = symbols[:bar_full] * filled + symbols[:bar_empty] * empty
#   color = if ratio > 0.8
#     COLORS[:green]
#   else
#     ((ratio > 0.4) ? COLORS[:yellow] : COLORS[:red])
#   end
#
#   color_text(bar, color)
# end


#
# def color_text(text, color)
#   return text if color.nil? || !config.color_enabled?
#   Rainbow(text).color(color)
# end
#
# def extract_numeric_value(formatted_value)
#   if formatted_value.is_a?(String) && formatted_value =~ /([0-9.]+)([kMBTQ])?/
#     value = $1.to_f
#     suffix = $2 || ""
#
#     multiplier = case suffix
#     when "k" then 1_000
#     when "M" then 1_000_000
#     when "B" then 1_000_000_000
#     when "T" then 1_000_000_000_000
#     when "Q" then 1_000_000_000_000_000
#     else 1
#     end
#
#     value * multiplier
#   else
#     formatted_value.to_f
#   end
# endendend