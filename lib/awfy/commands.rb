# frozen_string_literal: true

# This file serves as an index to load all commands at once

module Awfy
  # Commands namespace - contains all command implementations for the awfy CLI
  #
  # The Commands module organizes all benchmark command implementations in a single
  # namespace. Each command is implemented as a class that inherits from Commands::Base
  # and provides the specific benchmark functionality.
  #
  # Command classes:
  # - Commands::List - Lists available tests and benchmarks
  # - Commands::IPS - Runs Instructions Per Second benchmarks
  # - Commands::Memory - Runs memory profiling benchmarks
  # - Commands::Flamegraph - Generates flamegraphs for visualization
  # - Commands::Profiling - Runs CPU profiling
  # - Commands::YJITStats - Gathers YJIT-specific statistics
  # - Commands::CommitRange - Runs benchmarks across a range of git commits
  #
  # Each command has a consistent interface that is invoked by the Awfy::CLI class.
  module Commands
  end
end
