# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestShellInfo < Minitest::Test
    def test_initialize_with_all_attributes
      shell_info = ShellInfo.new(
        term: "xterm-256color",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      assert_equal "xterm-256color", shell_info.term
      assert_equal "en_US.UTF-8", shell_info.lang
      assert_equal "", shell_info.no_color
      assert shell_info.tty
    end

    def test_no_color_env_when_not_set
      shell_info = ShellInfo.new(
        term: "xterm",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      assert_equal "not set", shell_info.no_color_env
    end

    def test_no_color_env_when_set
      shell_info = ShellInfo.new(
        term: "xterm",
        lang: "en_US.UTF-8",
        no_color: "1",
        tty: true
      )

      assert_equal "set", shell_info.no_color_env
    end

    def test_color_status_disabled_by_env
      shell_info = ShellInfo.new(
        term: "xterm-256color",
        lang: "en_US.UTF-8",
        no_color: "1",
        tty: true
      )

      assert_equal "disabled by env", shell_info.color_status
    end

    def test_color_status_disabled_not_tty
      shell_info = ShellInfo.new(
        term: "xterm-256color",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: false
      )

      assert_equal "disabled (not a TTY)", shell_info.color_status
    end

    def test_color_status_likely_with_color_term
      shell_info = ShellInfo.new(
        term: "xterm-256color",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      assert_equal "likely", shell_info.color_status
    end

    def test_color_status_likely_with_xterm
      shell_info = ShellInfo.new(
        term: "xterm",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      assert_equal "likely", shell_info.color_status
    end

    def test_color_status_unlikely
      shell_info = ShellInfo.new(
        term: "dumb",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      assert_equal "unlikely", shell_info.color_status
    end

    def test_color_status_priority_no_color_over_tty
      # NO_COLOR env should take priority over TTY check
      shell_info = ShellInfo.new(
        term: "xterm-256color",
        lang: "en_US.UTF-8",
        no_color: "1",
        tty: false
      )

      assert_equal "disabled by env", shell_info.color_status
    end

    def test_term_with_various_values
      ["xterm", "xterm-256color", "screen", "dumb", "vt100"].each do |term_value|
        shell_info = ShellInfo.new(
          term: term_value,
          lang: "en_US.UTF-8",
          no_color: "",
          tty: true
        )

        assert_equal term_value, shell_info.term
      end
    end

    def test_lang_with_various_locales
      ["en_US.UTF-8", "ja_JP.UTF-8", "C", "POSIX"].each do |lang_value|
        shell_info = ShellInfo.new(
          term: "xterm",
          lang: lang_value,
          no_color: "",
          tty: true
        )

        assert_equal lang_value, shell_info.lang
      end
    end

    def test_tty_boolean_values
      shell_info_true = ShellInfo.new(
        term: "xterm",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      shell_info_false = ShellInfo.new(
        term: "xterm",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: false
      )

      assert_equal true, shell_info_true.tty
      assert_equal false, shell_info_false.tty
    end

    def test_no_color_with_different_values
      ["", "1", "true", "yes", "anything"].each do |no_color_value|
        shell_info = ShellInfo.new(
          term: "xterm",
          lang: "en_US.UTF-8",
          no_color: no_color_value,
          tty: true
        )

        if no_color_value == ""
          assert_equal "not set", shell_info.no_color_env
        else
          assert_equal "set", shell_info.no_color_env
        end
      end
    end

    def test_color_detection_with_screen_term
      shell_info = ShellInfo.new(
        term: "screen-256color",
        lang: "en_US.UTF-8",
        no_color: "",
        tty: true
      )

      # screen-256color contains "color"
      assert_equal "likely", shell_info.color_status
    end
  end
end
