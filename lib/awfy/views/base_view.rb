# frozen_string_literal: true

require "table_tennis"
require "rainbow"

module Awfy
  module Views
    # Base class for all views that handle output formatting
    class BaseView < Literal::Object
      include HasSession
      include ComparisonFormatters

      def sort_results(results, invert = false, &value_extractor)
        results.sort_by do |result|
          factor = (config.summary_order == "asc") ? 1 : -1
          factor *= -1 if invert
          value_extractor.call(result, factor)
        end
      end

      def has_runtime?(results_by_commit, runtime)
        results_by_commit.any? { |_, data| data[runtime] }
      end

      def performance_bar(value, max_value, width = 10)
        return "" if max_value.nil? || max_value.zero?

        # For terminals that don't support graphics well, use a shorter bar
        width = unicode_supported? ? width : [width, 5].min

        ratio = [value.to_f / max_value.to_f, 1.0].min
        filled = (ratio * width).round
        empty = width - filled

        bar = shell.symbols[:bar_full] * filled + shell.symbols[:bar_empty] * empty
        color = if ratio > 0.8
          :green
        else
          ((ratio > 0.4) ? :yellow : :red)
        end

        color_text(bar, color)
      end

      def color_text(text, color)
        return text if color.nil? || !color_supported?
        Rainbow(text).color(color)
      end

      def say_table(table, options = {})
        table_options = {
          title: table.title,
          theme: table.theme,
          mark: table.mark,
          headers: table.headers,
          columns: table.columns,
          color_scales: table.color_scales,
          separators: true,
          placeholder: " "
        }.merge!(options)

        rendered_table = TableTennis.new(table.rows, **table_options).to_s
        "#{rendered_table}\n#{table.order_description}"
      end
    end
  end
end
