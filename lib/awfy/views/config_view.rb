# frozen_string_literal: true

module Awfy
  module Views
    # View class for displaying configuration information
    class ConfigView < BaseView
      def display_configuration
        return unless verbose?

        say
        say "| on branch '#{git_client.current_branch}', and #{config.compare_with_branch ? "compare with branch: '#{config.compare_with_branch}', and " : ""}Runtime: #{config.humanized_runtime} and assertions: #{config.assert? || "skip"}", :cyan
        say "| Timestamp #{Time.now}", :cyan

        # Get terminal info from shell
        terminal_info = session.shell.terminal_info
        term_unicode = unicode_supported? ? "likely" : "unlikely"
        term_color = terminal_info.color_status

        say "| Display: " \
          "#{config.classic_style? ? "classic style" : "modern style"}, " \
          "Unicode: #{config.ascii_only? ? "disabled by flag" : term_unicode} [TERM=#{terminal_info.term}, LANG=#{terminal_info.lang}], " \
          "Color: #{config.no_color? ? "disabled by flag" : term_color} [NO_COLOR=#{terminal_info.no_color_env}, TTY=#{terminal_info.tty}]", :cyan

        format_and_display_config

        say
      end

      def format_and_display_config(config_data = config.to_h, color = :cyan)
        max_key_length = config_data.keys.map { |k| k.to_s.length }.max

        config_data.sort.each do |key, value|
          say(" - #{key.to_s.ljust(max_key_length)} : #{format_config_value(value)}", color)
        end
      end

      private

      def format_config_value(value)
        case value
        when Hash
          value.inspect
        when Array
          value.inspect
        when Symbol
          ":#{value}\n"
        else
          "#{value}\n"
        end
      end
    end
  end
end
