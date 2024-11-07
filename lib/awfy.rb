# frozen_string_literal: true

require "thor"

require "git"
require "json"
require "terminal-table"

require "benchmark/ips"
require "stackprof"
require "singed"
require "memory_profiler"

require_relative "awfy/version"
require_relative "awfy/suite"
require_relative "awfy/options"
require_relative "awfy/git_client"
require_relative "awfy/runner"
require_relative "awfy/run_report"
require_relative "awfy/command"
require_relative "awfy/list"
require_relative "awfy/ips"
require_relative "awfy/memory"
require_relative "awfy/flamegraph"
require_relative "awfy/yjit_stats"
require_relative "awfy/profiling"
require_relative "awfy/cli"

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
