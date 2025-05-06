# frozen_string_literal: true

require "literal"
require "thor"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem

# Configure inflections
loader.inflector.inflect(
  "cli" => "CLI",
  "ips" => "IPS",
  "yjit_stats" => "YJITStats"
)

# Configure special inflections for commands directory
loader.inflector.inflect(
  "commands/ips" => "Commands::IPS",
  "commands/yjit_stats" => "Commands::YJITStats"
)
loader.setup

module Awfy
  class << self
    # Include the DSL methods from the DSL module
    include Awfy::Dsl
  end
end
