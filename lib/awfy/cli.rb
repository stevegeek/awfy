# frozen_string_literal: true

module Awfy
  class CLI < Thor
    check_unknown_options!

    def self.exit_on_failure? = true

    # Runtime/comparison options
    class_option :runtime, enum: ["both", "yjit", "mri"], default: "both", desc: "Run with and/or without YJIT enabled"
    class_option :compare_with_branch, type: :string, desc: "Name of branch to compare with results on current branch"
    class_option :compare_control, type: :boolean, desc: "When comparing branches, also re-run all control blocks too", default: false
    class_option :commit_range, type: :string, desc: "Range of commits to benchmark (e.g., 'main..HEAD' or 'abc123..def456')"
    class_option :ignore_commits, type: :string, desc: "Comma-separated list of commit hashes to skip"
    class_option :assert, type: :boolean, desc: "Assert that the results are within a certain threshold coded in the tests", default: false

    # Output/display options
    class_option :summary, type: :boolean, desc: "Generate a summary of the results", default: true
    class_option :summary_order, enum: ["desc", "asc", "leader"], default: "leader", desc: "Sort order for summary tables: ascending, descending, or leaderboard (command specific, e.g. fastest to slowest for IPS)"
    class_option :quiet, type: :boolean, desc: "Silence output. Note if `summary` option is enabled the summaries will be displayed even if `quiet` enabled.", default: false
    class_option :verbose, type: :numeric, desc: "Verbose output level (0=none, 1=basic, 2=detailed, 3=debug)", default: 0
    class_option :v, type: :boolean, desc: "Shorthand for --verbose=1", default: false

    # Test execution options
    class_option :runner, enum: RunnerTypes.values, default: "immediate", desc: "Type of runner to use for benchmark execution"
    class_option :test_warm_up, type: :numeric, default: 1.0, desc: "Number of seconds to warmup the IPS benchmark"
    class_option :test_time, type: :numeric, default: 3.0, desc: "Number of seconds to run the IPS benchmark"
    class_option :test_iterations, type: :numeric, default: 1_000_000, desc: "Number of iterations to run the test"

    # File path options
    class_option :setup_file_path, type: :string, default: "./benchmarks/setup", desc: "Path to the setup file"
    class_option :tests_path, type: :string, default: "./benchmarks/tests", desc: "Path to the tests files"

    # Storage options
    class_option :storage_backend, type: :string, default: StoreAliases::SQLite.value, desc: "Storage backend for benchmark results ('memory', 'json' or the default, 'sqlite')"
    class_option :storage_name, type: :string, default: "benchmark_history", desc: "Name for the storage repository (database name or directory)"
    class_option :retention_policy, type: :string, default: "keep", desc: "Retention policy for benchmark results (keep or date)"
    class_option :retention_days, type: :numeric, default: 30, desc: "Number of days to keep results (only used with 'date' policy)"

    # Output formatting options
    class_option :list, type: :boolean, desc: "Display output in list format instead of table", default: false
    class_option :color, enum: ["auto", "light", "dark", "off", "ansi"], default: "auto", desc: "Color output mode (auto, light, dark, off, or ansi for ANSI-only terminals)"

    # Register subcommands
    desc "suite SUBCOMMAND", "Suite-related commands (list, debug)"
    subcommand "suite", CLICommands::Suite

    desc "config SUBCOMMAND", "Configuration-related commands (inspect, save)"
    subcommand "config", CLICommands::Config

    desc "ips SUBCOMMAND", "IPS-related commands (start)"
    subcommand "ips", CLICommands::IPS

    desc "memory SUBCOMMAND", "Memory-related commands (start)"
    subcommand "memory", CLICommands::Memory

    desc "flamegraph SUBCOMMAND", "Flamegraph-related commands (generate)"
    subcommand "flamegraph", CLICommands::Flamegraph

    desc "profile SUBCOMMAND", "Profile-related commands (start)"
    subcommand "profile", CLICommands::Profile

    desc "yjit-stats SUBCOMMAND", "YJIT stats-related commands (start)"
    subcommand "yjitstats", CLICommands::YJITStats

    desc "store SUBCOMMAND", "Store-related commands (clean)"
    subcommand "store", CLICommands::Store
  end
end
