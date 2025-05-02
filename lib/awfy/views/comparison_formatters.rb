# frozen_string_literal: true

module Awfy
  module Views
    # Common methods for formatting comparison results
    module ComparisonFormatters
      def format_change(ratio)
        if ratio > 1.0
          "+#{((ratio - 1) * 100).round(1)}%"
        elsif ratio < 1.0
          "-#{((1 - ratio) * 100).round(1)}%"
        else
          "No change"
        end
      end

      def format_comparison(ratio, higher_is_better = true, precision = 2)
        return "baseline" if ratio == 1.0

        if higher_is_better
          if ratio > 1.0
            "#{ratio.round(precision)}x faster"
          else
            "#{(1.0 / ratio).round(precision)}x slower"
          end
        elsif ratio < 1.0
          "#{(1.0 / ratio).round(precision)}x better"
        else
          "#{ratio.round(precision)}x worse"
        end
      end

      def format_result_diff(result)
        if result[:is_baseline]
          "-"
        elsif result[:overlaps] || result[:diff_times].zero?
          "same"
        elsif result[:diff_times] == Float::INFINITY
          "∞"
        elsif result[:diff_times]
          "#{result[:diff_times]} x"
        else
          "?"
        end
      end

      def format_memory_diff(result)
        if result[:is_baseline]
          "-"
        elsif !result[:memory_diff]
          "N/A"
        elsif result[:memory_diff] == 1.0
          "same"
        elsif result[:memory_diff] < 1.0
          "#{((1 - result[:memory_diff]) * 100).round(1)}% better"
        else
          "#{((result[:memory_diff] - 1) * 100).round(1)}% worse"
        end
      end

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
    end
  end
end
