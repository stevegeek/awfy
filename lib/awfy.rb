# frozen_string_literal: true

# External dependencies (still needed)
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

loader.setup

module Awfy
  class << self
    def group(name, &)
      suite.group(name, &)
    end

    def groups
      suite.groups
    end

    def report(name, &)
      suite.report(name, &)
    end

    def control(name, &)
      suite.control(name, &)
    end

    def test(name, &)
      suite.test(name, &)
    end

    def suite
      @suite ||= Suite.new
    end
  end
end
