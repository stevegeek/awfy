# frozen_string_literal: true

require "literal"

require "thor"
require "git"
require "json"
require "terminal-table"
require "benchmark/ips"
require "stackprof"
require "vernier"
require "memory_profiler"

# Set up Zeitwerk autoloading
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
  DEFAULT_BACKEND = "json"

  class << self
    # Include the DSL methods from the DSL module
    include Awfy::Dsl
  end
end
