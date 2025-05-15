# frozen_string_literal: true

require "literal"
require "thor"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem

# Configure inflections
loader.inflector.inflect(
  "cli" => "CLI",
  "cli_command" => "CLICommand",
  "cli_commands" => "CLICommands",
  "ips" => "IPS",
  "ips_result" => "IPSResult",
  "yjit_stats" => "YJITStats",
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
