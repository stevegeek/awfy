# frozen_string_literal: true

# SimpleCov must be loaded before any application code
if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"

  SimpleCov.start do
    add_filter "/test/"
    add_filter "/vendor/"

    # Group coverage by type
    add_group "Commands", "lib/awfy/cli_commands"
    add_group "Commands (legacy)", "lib/awfy/commands"
    add_group "Runners", "lib/awfy/runners"
    add_group "Stores", "lib/awfy/stores"
    add_group "Views", "lib/awfy/views"
    add_group "Suites", "lib/awfy/suites"
    add_group "Jobs", "lib/awfy/jobs"
    add_group "Core", "lib/awfy"

    # Set minimum coverage threshold (warning only, not failing build yet)
    # minimum_coverage 80  # Uncomment when we reach this goal
    # minimum_coverage_by_file 50  # Uncomment when we reach this goal

    # Print coverage summary
    at_exit do
      puts "\n" + "=" * 80
      puts "CODE COVERAGE SUMMARY"
      puts "=" * 80
      puts "Coverage report: file://#{SimpleCov.coverage_dir}/index.html"
      puts "=" * 80
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "awfy"

# Eagerly load all classes for coverage measurement
if ENV["COVERAGE"] || ENV["CI"]
  # Load all error classes
  Awfy::Errors::SuiteError
  Awfy::Errors::NoBaselineError
  Awfy::Errors::SuiteEmptyError
  Awfy::Errors::GroupNotFoundError
  Awfy::Errors::GroupEmptyError
  Awfy::Errors::ReportNotFoundError
  Awfy::Errors::TestNotFoundError

  # Load result types
  Awfy::IPSResult
  Awfy::MemoryResult

  # Load retention policies
  Awfy::RetentionPolicies::KeepAll
  Awfy::RetentionPolicies::KeepNone
  Awfy::RetentionPolicies::DateBased

  # Load stores
  Awfy::Stores::Memory
  Awfy::Stores::Json
  Awfy::Stores::Sqlite

  # Load config classes
  Awfy::ConfigLocation
  Awfy::ConfigLoader

  # Load shell info
  Awfy::ShellInfo

  # Load runners
  Awfy::Runners::Parallel::ForkedRunner
  Awfy::Runners::Parallel::ThreadRunner
  Awfy::Runners::Sequential::ImmediateRunner
  Awfy::Runners::Sequential::SpawnRunner
  Awfy::Runners::Sequential::CommitRangeRunner
  Awfy::Runners::Sequential::BranchComparisonRunner

  # Load jobs
  Awfy::Jobs::IPS
  Awfy::Jobs::Memory
  Awfy::Jobs::RunGroup
  Awfy::Jobs::Flamegraph
  Awfy::Jobs::Profiling
  Awfy::Jobs::YJITStats

  # Load commands
  Awfy::Commands::IPS
  Awfy::Commands::Memory
  Awfy::Commands::Config
  Awfy::Commands::Flamegraph
  Awfy::Commands::Profile
  Awfy::Commands::Results
  Awfy::Commands::Store
  Awfy::Commands::Suite
  Awfy::Commands::YJITStats

  # Load suites
  Awfy::Suites::Loader
  Awfy::Suites::BaselineTest
  Awfy::Suites::ControlTest

  # Load views
  Awfy::Views::ProgressBar
  Awfy::Views::TimedProgressBar
  Awfy::Views::ConfigView
  Awfy::Views::CommitHelpers
  Awfy::Views::IPS::SummaryTable
  Awfy::Views::IPS::SummaryView
  Awfy::Views::Memory::SummaryTable
  Awfy::Views::Suites::ListTable
  Awfy::Views::Suites::ListView

  # Load CLI commands
  Awfy::CLICommands::Base
  Awfy::CLICommands::Config
  Awfy::CLICommands::Flamegraph
  Awfy::CLICommands::IPS
  Awfy::CLICommands::Memory
  Awfy::CLICommands::Profile
  Awfy::CLICommands::Results
  Awfy::CLICommands::Store
  Awfy::CLICommands::Suite
  Awfy::CLICommands::YJITStats

  # Load CLI
  Awfy::CLI

  # Load version
  Awfy::VERSION
end

require "minitest/autorun"
