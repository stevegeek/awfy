# frozen_string_literal: true

# This file serves as an index to load all commands at once

require_relative "commands/base"
require_relative "commands/list"
require_relative "commands/ips"
require_relative "commands/memory"
require_relative "commands/flamegraph"
require_relative "commands/profiling"
require_relative "commands/yjit_stats"
require_relative "commands/commit_range"

module Awfy
  module Commands
    # This module is intentionally empty
    # It serves as a namespace for all command classes
  end
end