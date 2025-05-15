# frozen_string_literal: true

module Awfy
  # Color mode options for terminal output
  class ColorMode < Literal::Enum(String)
    AUTO = new("auto")
    LIGHT = new("light")
    DARK = new("dark")
    OFF = new("off")
    ANSI = new("ansi")
  end
end
