# frozen_string_literal: true

module Awfy
  # Suite subcommand for managing test suites
  class SuiteCommand < CLICommand

    desc "list [GROUP]", "List all tests in a group"
    def list(group_name = nil)
      # Create a shell instance
      shell = Awfy::Shell.new(config:)

      # Initialize dependencies
      git_client = GitClient.new(path: Dir.pwd)
      results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
      session = Awfy::Session.new(shell:, config:, git_client:, results_store:)
      suite = Suites::Loader.new(session:).load
      result_manager = Awfy::ResultManager.new(session:)

      # Check if the test suite has tests
      unless suite.tests?
        shell.say_error_and_exit "Test suite (in '#{config.tests_path}') has no tests defined..."
      end

      # Run the list command
      Runners.immediate(suite:, session:).run(group_name) do |group|
        Commands::List.new(session:, group:, benchmarker: Benchmarker.new(session:, result_manager:))
      end
    rescue ArgumentError => e
      shell.say_error_and_exit e.message
    end
  end

  # Configuration command subclass
  class ConfigCommand < CLICommand
    desc "inspect [LOCATION]", "Show current configuration settings"
    def inspect(location = nil)
      shell = Awfy::Shell.new(config:)
      git_client = GitClient.new(path: Dir.pwd)
      results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
      session = Awfy::Session.new(shell:, config:, git_client:, results_store:)

      Commands::Config.new(session:).inspect(location)
    end

    desc "save [LOCATION]", "Save current configuration to a file"
    def save(location = nil)
      shell = Awfy::Shell.new(config:)
      git_client = GitClient.new(path: Dir.pwd)
      results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
      session = Awfy::Session.new(shell:, config:, git_client:, results_store:)

      Commands::Config.new(session:).save(location)
    end
  end

  class CLI < CLICommand
    def self.exit_on_failure? = true

    # Register subcommands
    desc "suite SUBCOMMAND", "Suite-related commands (list, run, etc.)"
    subcommand "suite", SuiteCommand

    desc "config SUBCOMMAND", "Configuration-related commands (inspect, save)"
    subcommand "config", ConfigCommand
    #
    # class_option :runtime, enum: ["both", "yjit", "mri"], default: "both", desc: "Run with and/or without YJIT enabled"
    # class_option :compare_with_branch, type: :string, desc: "Name of branch to compare with results on current branch"
    # class_option :compare_control, type: :boolean, desc: "When comparing branches, also re-run all control blocks too", default: false
    #
    # class_option :summary, type: :boolean, desc: "Generate a summary of the results", default: true
    # class_option :summary_order, enum: ["desc", "asc", "leader"], default: "leader", desc: "Sort order for summary tables: ascending, descending, or leaderboard (command specific, e.g. fastest to slowest for IPS)"
    # class_option :quiet, type: :boolean, desc: "Silence output. Note if `summary` option is enabled the summaries will be displayed even if `quiet` enabled.", default: false
    # class_option :verbose, type: :boolean, desc: "Verbose output", default: false
    # class_option :test_warm_up, type: :numeric, default: 1, desc: "Number of seconds to warmup the IPS benchmark"
    # class_option :test_time, type: :numeric, default: 3, desc: "Number of seconds to run the IPS benchmark"
    # class_option :test_iterations, type: :numeric, default: 1_000_000, desc: "Number of iterations to run the test"
    # class_option :setup_file_path, type: :string, default: "./benchmarks/setup", desc: "Path to the setup file"
    # class_option :tests_path, type: :string, default: "./benchmarks/tests", desc: "Path to the tests files"
    # class_option :storage_backend, type: :string, default: DEFAULT_BACKEND, desc: "Storage backend for benchmark results (json or sqlite)"
    # class_option :storage_name, type: :string, default: "benchmark_history", desc: "Name for the storage repository (database name or directory)"
    # class_option :retention_policy, type: :string, default: "keep", desc: "Retention policy for benchmark results (keep or date)"
    # class_option :retention_days, type: :numeric, default: 30, desc: "Number of days to keep results (only used with 'date' policy)"
    #
    # # TODO: implement assert option
    # # class_option :assert, type: :boolean, desc: "Assert that the results are within a certain threshold coded in the tests"

    # Output formatting

    class_option :list, type: :boolean, desc: "Display output in list format instead of table", default: false
    # class_option :classic_style, type: :boolean, desc: "Use classic table style instead of modern style", default: false
    # class_option :ascii_only, type: :boolean, desc: "Use only ASCII characters (no Unicode)", default: false
    # class_option :no_color, type: :boolean, desc: "Disable colored output", default: false

    # desc "list [GROUP]", "List all tests in a group"
    # def list(group_name = nil)
    #   # List command always uses single run runner
    #   shell = Awfy::Shell.new(config:)
    #   git_client = GitClient.new(path: Dir.pwd)
    #   results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
    #   session = Awfy::Session.new(shell:, config:, git_client:, results_store:)
    #   suite = Suites::Loader.new(session:).load
    #   result_manager = Awfy::ResultManager.new(session:)
    #   unless suite.tests?
    #     shell.say_error_and_exit "Test suite (in '#{config.tests_path}') has no tests defined..."
    #   end
    #   Runners.immediate(suite:, session:).run(group_name) do |group|
    #     Commands::List.new(session:, group:, benchmarker: Benchmarker.new(session:, result_manager:))
    #   end
    # rescue ArgumentError => e
    #   shell.say_error_and_exit e.message
    # end

    # desc "ips [GROUP] [REPORT] [TEST]", "Run IPS benchmarks. Can generate summary across implementations, runtimes and branches."
    # def ips(group = nil, report = nil, test = nil)
    #   say "Running IPS for:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # Run the benchmark using the appropriate runner
    #   if awfy_options.compare_with_branch
    #     # Branch comparison runner expects main_branch and comparison_branch
    #     current_branch = git_client.current_branch
    #     comparison_branch = awfy_options.compare_with_branch
    #     runner.run(current_branch, comparison_branch, group) do |results|
    #       # Display results using appropriate view
    #       display_ips_results(results)
    #     end
    #   elsif awfy_options.commit_range
    #     # Commit range runner expects start_commit and end_commit
    #     commits = awfy_options.commit_range.split("..")
    #     start_commit = commits[0]
    #     end_commit = commits[1] || "HEAD"
    #     runner.run(start_commit, end_commit, group) do |results|
    #       # Display results using appropriate view
    #       display_ips_results(results)
    #     end
    #   else
    #     # Single run runner just needs a group
    #     runner.run(group) do |group_data|
    #       # Run the IPS command with the group data
    #       Commands::IPS.new(runner, shell, git_client: git_client, options: awfy_options).benchmark(group_data, report, test)
    #     end
    #   end
    # end
    #
    # desc "memory [GROUP] [REPORT] [TEST]", "Run memory profiling. Can generate summary across implementations, runtimes and branches."
    # def memory(group = nil, report = nil, test = nil)
    #   say "Running memory profiling for:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # Run the benchmark using the appropriate runner
    #   if awfy_options.compare_with_branch
    #     # Branch comparison runner expects main_branch and comparison_branch
    #     current_branch = git_client.current_branch
    #     comparison_branch = awfy_options.compare_with_branch
    #     runner.run(current_branch, comparison_branch, group) do |results|
    #       # Display results using appropriate view
    #       display_memory_results(results)
    #     end
    #   elsif awfy_options.commit_range
    #     # Commit range runner expects start_commit and end_commit
    #     commits = awfy_options.commit_range.split("..")
    #     start_commit = commits[0]
    #     end_commit = commits[1] || "HEAD"
    #     runner.run(start_commit, end_commit, group) do |results|
    #       # Display results using appropriate view
    #       display_memory_results(results)
    #     end
    #   else
    #     # Single run runner just needs a group
    #     runner.run(group) do |group_data|
    #       # Run the memory command with the group data
    #       Commands::Memory.new(runner, shell, git_client: git_client, options: awfy_options).benchmark(group_data, report, test)
    #     end
    #   end
    # end
    #
    # desc "flamegraph GROUP REPORT TEST", "Run flamegraph profiling"
    # def flamegraph(group, report, test)
    #   say "Creating flamegraph for:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # Flamegraph always uses single run runner
    #   runner.run(group) do |group_data|
    #     Commands::Flamegraph.new(runner, shell, git_client: git_client, options: awfy_options).generate(group_data, report, test)
    #   end
    # end
    #
    # desc "profile [GROUP] [REPORT] [TEST]", "Run CPU profiling"
    # def profile(group = nil, report = nil, test = nil)
    #   say "Run profiling of:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # Profiling always uses single run runner
    #   runner.run(group) do |group_data|
    #     Commands::Profiling.new(runner, shell).generate(group_data, report, test)
    #   end
    # end
    #
    # desc "yjit-stats [GROUP] [REPORT] [TEST]", "Run YJIT stats"
    # def yjit_stats(group = nil, report = nil, test = nil)
    #   if options[:runtime] == "mri"
    #     say_error "Must run with YJIT runtime (if 'both' is selected the command only runs with yjit)"
    #     exit(1)
    #   end
    #
    #   say "Running YJIT stats for:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # YJIT stats always uses single run runner
    #   runner.run(group) do |group_data|
    #     Commands::YJITStats.new(runner, shell).benchmark(group_data, report, test)
    #   end
    # end
    #
    # desc "clean", "Clean up benchmark results based on retention policy"
    # def clean
    #   # Create the retention policy first
    #   policy = RetentionPolicies.create(awfy_options.retention_policy)
    #
    #   # Get the result store and pass the retention policy
    #   result_store = Stores.create(awfy_options.storage_backend, awfy_options, policy)
    #
    #   # Clean results
    #   result_store.clean_results
    #
    #   say "Cleaned benchmark results using '#{policy.name}' retention policy"
    # end
    #
    # desc "compare <benchmark_type> <COMMIT_RANGE> [GROUP] [REPORT] [TEST]", "Run benchmarks across a range of commits"
    # option :ignore_commits, type: :string, desc: "Commits to ignore, either individual hashes (comma-separated) or ranges 'hash1..hash2' (inclusive)"
    # option :use_cached, type: :boolean, default: true, desc: "Use cached results if available"
    # option :results_only, type: :boolean, default: false, desc: "Only display previously saved results without running new benchmarks"
    # def compare(benchmark_type, commit_range, group = nil, report = nil, test = nil)
    #   unless ["ips", "memory", "profile"].include?(benchmark_type)
    #     say_error "Unsupported benchmark type: #{benchmark_type}. Use one of: ips, memory, profile"
    #     exit(1)
    #   end
    #
    #   # Set commit range in options
    #   opts = awfy_options.to_h.merge(commit_range: commit_range)
    #   custom_options = Options.new(**opts)
    #
    #   say "Comparing #{benchmark_type} benchmarks across commits #{commit_range}:"
    #   say "> #{requested_tests(group, report, test)}..."
    #
    #   # Create a commit range runner specifically for this command
    #   commit_runner = Runners.commit_range(Awfy.suite, shell, git_client, custom_options)
    #
    #   # Parse the commit range
    #   commits = commit_range.split("..")
    #   start_commit = commits[0]
    #   end_commit = commits[1] || "HEAD"
    #
    #   # Run across the commit range
    #   commit_runner.run(start_commit, end_commit, group) do |results|
    #     # Display results based on benchmark type
    #     case benchmark_type
    #     when "ips"
    #       display_ips_results(results)
    #     when "memory"
    #       display_memory_results(results)
    #     when "profile"
    #       # Profile results are displayed by the profile command
    #       # We don't need to do anything special here
    #     end
    #   end
    # end
    #
    #
    # def runner
    #   # Create the appropriate runner based on options
    #   @runner ||= if awfy_options.commit_range
    #     Runners.commit_range(Awfy.suite, shell, git_client, awfy_options)
    #   elsif awfy_options.compare_with_branch
    #     Runners.on_branches(Awfy.suite, shell, git_client, awfy_options)
    #   else
    #     Runners.single(Awfy.suite, shell, git_client, awfy_options)
    #   end
    # end
    #
    # def requested_tests(group, report = nil, test = nil)
    #   tests = [group, report, test].compact
    #   return "(all)" if tests.empty?
    #   tests.join("/")
    # end
    #
    # def git_client
    #   @_git_client ||= GitClient.new(Dir.pwd)
    # end
    #
    # def git_current_branch_name = git_client.current_branch
    #
    # def yjit_only? = options[:runtime] == "yjit"
    #
    # def both_runtimes? = options[:runtime] == "both"
    #
    # def verbose? = options[:verbose]
    #
    # def show_summary? = options[:summary]
    #
    # # Display IPS benchmark results using the appropriate view
    # def display_ips_results(results)
    #   if awfy_options.summary
    #     require "awfy/views/ips/composite_view"
    #     view = Awfy::Views::IPS::CompositeView.new(results, shell, awfy_options)
    #     view.render
    #   end
    # end
    #
    # # Display memory benchmark results using the appropriate view
    # def display_memory_results(results)
    #   if awfy_options.summary
    #     require "awfy/views/memory/composite_view"
    #     view = Awfy::Views::Memory::CompositeView.new(results, shell, awfy_options)
    #     view.render
    #   end
    # end
  end
end
