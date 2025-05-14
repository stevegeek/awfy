# frozen_string_literal: true

module Awfy
  # Configuration file locations
  class ConfigLocation < Literal::Enum(String)
    Home = new("home")
    Setup = new("setup")
    Suite = new("suite")
    Current = new("current")
  end
end