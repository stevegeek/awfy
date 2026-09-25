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
# lib/awfy/rails.rb and lib/awfy/rails/ load only through `require "awfy/rails"`: they refer
# to Rails at call time, and a Rails production boot eager-loads every Zeitwerk loader.
loader.ignore("#{__dir__}/awfy/rails.rb", "#{__dir__}/awfy/rails")
loader.setup

module Awfy
  class << self
    # Include the DSL methods from the DSL module
    include Awfy::Dsl
  end
end

# Assigned outside the module body: `module Awfy ... end` opens a fresh local scope that
# cannot see the `loader` local above, so `LOADER = loader` inside it raises NameError.
Awfy::LOADER = loader
