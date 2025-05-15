# frozen_string_literal: true

require "bigdecimal"

module Awfy
  module Views
    # Common methods for formatting comparison results
    module ComparisonFormatters
      def to_big_decimal(value)
        BigDecimal(value.to_s)
      end

      def format_change(ratio)
        bd_ratio = to_big_decimal(ratio)
        bd_one = BigDecimal("1.0")

        if bd_ratio > bd_one
          change = ((bd_ratio - bd_one) * 100).round(1)
          "+%.1f%%" % change
        elsif bd_ratio < bd_one
          change = ((bd_one - bd_ratio) * 100).round(1)
          "-%0.1f%%" % change
        else
          "No change"
        end
      end

      def format_comparison(ratio, higher_is_better = true, precision = 2)
        bd_ratio = to_big_decimal(ratio)
        bd_one = BigDecimal("1.0")

        return "baseline" if bd_ratio == bd_one

        if higher_is_better
          if bd_ratio > bd_one
            "%.1fx faster" % bd_ratio.round(precision)
          else
            "%.1fx slower" % (bd_one / bd_ratio).round(precision)
          end
        elsif bd_ratio < bd_one
          "%.1fx better" % (bd_one / bd_ratio).round(precision)
        else
          "%.1fx worse" % bd_ratio.round(precision)
        end
      end

      def format_result_diff(result)
        if result[:is_baseline]
          "-"
        elsif result[:overlaps] || result[:diff_times]&.zero?
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
        else
          bd_memory_diff = to_big_decimal(result[:memory_diff])
          bd_one = BigDecimal("1.0")
          if bd_memory_diff == bd_one
            "same"
          elsif bd_memory_diff < bd_one
            change = ((bd_one - bd_memory_diff) * 100).round(1)
            "%.1f%% better" % change
          else
            change = ((bd_memory_diff - bd_one) * 100).round(1)
            "%.1f%% worse" % change
          end
        end
      end

      def humanize_scale(number, round_to: 0)
        suffixes = ["", "k", "M", "B", "T", "Q"]

        return "0" if number.zero?
        number = number.respond_to?(:to_f) ? number.to_f : number
        number = number.round(round_to)
        scale = (Math.log10(number) / 3).to_i
        scale = 0 if scale < 0 || scale >= suffixes.size
        suffix = suffixes[scale]
        scaled_value = number.to_f / (1000**scale)

        if scale == 0
          "%d%s" % [scaled_value.to_i, suffix]
        else
          "%.1f%s" % [scaled_value, suffix]
        end
      end

      module_function :humanize_scale
    end
  end
end
