# frozen_string_literal: true

module Awfy
  # Verbosity levels
  class VerbosityLevel < Literal::Enum(Integer)
    MUTE = new(-1)
    NONE = new(0)
    BASIC = new(1)
    DETAILED = new(2)
    DEBUG = new(3)
  end
end
