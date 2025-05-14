# frozen_string_literal: true

module Awfy
  class ShellInfo < Literal::Data
    prop :term, String
    prop :lang, String
    prop :no_color, String
    prop :tty, _Boolean

    def no_color_env
      (no_color == "") ? "not set" : "set"
    end

    def color_status
      if no_color != ""
        "disabled by env"
      elsif !tty
        "disabled (not a TTY)"
      else
        (term.include?("color") || term == "xterm") ? "likely" : "unlikely"
      end
    end
  end
end
