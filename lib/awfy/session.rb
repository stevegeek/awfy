# frozen_string_literal: true

module Awfy
  class Session < Literal::Data
    prop :shell, Awfy::Shell
    prop :config, Awfy::Config
    prop :git_client, Awfy::GitClient, default: -> { Awfy::GitClient.new(Dir.pwd) }
    prop :results_store, Awfy::Stores::Base

    def say(...) = shell.say(...)

    def say_error(...) = shell.say_error(...)

    def verbose? = config.verbose?

    # Output configuration information
    def say_configuration
      return unless config.verbose?
      shell.say
      shell.say "| on branch '#{git_client.current_branch}', and #{config.compare_with_branch ? "compare with branch: '#{config.compare_with_branch}', and " : ""}Runtime: #{config.humanized_runtime} and assertions: #{config.assert? || "skip"}", :cyan
      shell.say "| Timestamp #{@start_time}", :cyan

      # Get terminal info from shell
      terminal_info = shell.terminal_info
      term_unicode = shell.unicode_supported? ? "likely" : "unlikely"
      term_color = terminal_info.color_status

      shell.say "| Display: " +
        "#{config.classic_style? ? "classic style" : "modern style"}, " +
        "Unicode: #{config.ascii_only? ? "disabled by flag" : term_unicode} [TERM=#{terminal_info.term}, LANG=#{terminal_info.lang}], " +
        "Color: #{config.no_color? ? "disabled by flag" : term_color} [NO_COLOR=#{terminal_info.no_color_env}, TTY=#{terminal_info.tty}]", :cyan

      # Display progress bar information
      shell.say "| Progress bar: #{config.test_warm_up}s warmup + #{config.test_time}s runtime per test", :cyan
      shell.say
    end
  end
end
