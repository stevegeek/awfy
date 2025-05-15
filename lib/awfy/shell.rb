# frozen_string_literal: true

module Awfy
  # Shell class wraps Thor::Shell and provides consistent terminal capability detection.
  # It determines whether to use Color or Basic shell based on the terminal's capabilities.
  class Shell < Literal::Object
    prop :config, Config

    # todo: if quiet silence?

    def after_initialize
      @shell = detect_shell
    end

    # TODO: enums
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

    # Get appropriate symbols based on terminal capabilities
    def symbols
      unicode_supported? ? UNICODE_SYMBOLS : ASCII_SYMBOLS
    end

    def say_error(message, *args)
      if color_supported? && args.empty?
        return @shell.say_error(message, :red, true)
      end
      @shell.say_error(message, *args)
    end

    def say_error_and_exit(...)
      say_error(...)
      exit(1)
    end

    # Forward all method calls to the underlying Thor shell
    def method_missing(method_name, *args, &block)
      if @shell.respond_to?(method_name)
        @shell.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @shell.respond_to?(method_name, include_private) || super
    end

    # Return terminal information
    def terminal_info
      @terminal_info ||= ShellInfo.new(
        term: ENV["TERM"] || "not set",
        lang: ENV["LANG"] || "not set",
        no_color: ENV["NO_COLOR"] || "",
        tty: $stdout.tty?
      )
    end

    # Check if Unicode characters are supported by the terminal
    def unicode_supported?
      @unicode_supported ||= begin
        info = terminal_info
        info.term.include?("xterm") || info.term.include?("256color") ||
          info.lang.include?("UTF") || info.lang.include?("utf")
      end
    end

    # Check if color is supported by the terminal
    def color_supported?
      return false if @config&.color_off?

      @color_supported ||= begin
        info = terminal_info
        info.no_color.empty? && (info.term.include?("color") || info.term == "xterm") && info.tty
      end
    end

    private

    # Detect the appropriate shell type based on terminal capabilities
    def detect_shell
      if color_supported?
        Thor::Shell::Color.new
      else
        Thor::Shell::Basic.new
      end
    end
  end
end
