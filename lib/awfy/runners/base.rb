# frozen_string_literal: true

require "fileutils"

module Awfy
  module Runners
    # Base defines the common interface for all runner implementations
    # Runners are responsible for handling the execution environment for benchmarks
    # including process management and git operations when needed
    class Base
      def initialize(suite, shell, git_client, options)
        @suite = suite
        @shell = shell
        @git_client = git_client
        @options = options
        @groups = suite.groups
        @start_time = nil
      end

      attr_reader :start_time, :suite, :shell, :git_client, :options, :groups

      # Execute a benchmark run
      # This is the main entry point for any runner implementation
      # @param group [String, nil] Optional group name to run
      # @yield [Group] Yields the group being run to the block
      def run(group = nil, &block)
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      # Run a specific benchmark group
      # @param group_name [String] Name of the group to run
      # @yield [Group] Yields the group being run to the block
      def run_group(group_name, &block)
        group = @groups[group_name]
        raise "Group '#{group_name}' not found" unless group
        yield group
      end

      # Run all benchmark groups
      # @yield [Group] Yields each group being run to the block
      def run_groups(&block)
        @groups.keys.each do |group_name|
          run_group(group_name, &block)
        end
      end

      # Run cleanup with the current retention policy
      # This ensures old results are cleaned up before each benchmark run
      def run_cleanup_with_retention_policy
        # Skip if RetentionPolicies module is not defined (in tests)
        return unless defined?(Awfy::RetentionPolicies)

        # Create the retention policy using the module method
        policy = Awfy::RetentionPolicies.create(options.retention_policy, options.to_h)

        # Get the result store from the Stores module and pass the retention policy
        result_store = Awfy::Stores.create(options.storage_backend, options, policy)
        result_store.clean_results

        # Show info if verbose
        if options.verbose?
          shell.say "| Applied '#{policy.name}' retention policy"
          shell.say
        end
      end

      # Run a command in a fresh Ruby process
      # @param command_type [String] The command type (ips, memory, etc.)
      # @param group_name [String, nil] Optional group name to run
      # @param report_name [String, nil] Optional report name to run
      # @param test_name [String, nil] Optional test name to run
      # @param extra_options [Hash] Additional command-line options to pass
      # @return [Boolean] Whether the command succeeded
      def run_in_fresh_process(command_type, group_name = nil, report_name = nil, test_name = nil, extra_options = {})
        # Build the command to run the benchmark in a separate process
        cmd = ["ruby", "-r", "./lib/awfy", "exe/awfy", command_type]

        # Add group, report, test if provided
        cmd << group_name if group_name
        cmd << report_name if report_name
        cmd << test_name if test_name

        # Add standard options
        cmd << "--save"   # Always save results for collection
        cmd << "--runtime=#{options.runtime}" if options.runtime
        cmd << "--test-time=#{options.test_time}" if options.test_time
        cmd << "--test-warm-up=#{options.test_warm_up}" if options.test_warm_up
        cmd << "--verbose" if options.verbose?
        cmd << "--classic-style" if options.classic_style?
        cmd << "--ascii-only" if options.ascii_only?
        cmd << "--no-color" if options.no_color?
        
        # Add storage options
        cmd << "--storage-backend=#{options.storage_backend}" if options.storage_backend
        cmd << "--storage-name=#{options.storage_name}" if options.storage_name
        
        # Add any extra options
        extra_options.each do |key, value|
          if value == true
            cmd << "--#{key}"
          elsif value != false && !value.nil?
            cmd << "--#{key}=#{value}"
          end
        end

        # Execute and capture output
        system(*cmd)
      end

      # Safely checkout a git reference, run a block, and return to the original state
      # @param ref [String] The git reference (branch, commit, etc.) to checkout
      # @yield Execute the given block with the reference checked out
      def safe_checkout(ref)
        # Save the current state
        current_branch = git_client.current_branch
        git_client.lib.stash_save("awfy auto stash")

        begin
          # Checkout the reference (branch or commit)
          git_client.checkout(ref)

          # Run the block with the ref checked out
          yield
        ensure
          # Return to original branch
          git_client.checkout(current_branch)

          # Pop stashed changes
          begin
            git_client.lib.command("stash", "pop")
          rescue
            # Ignore stash pop errors
          end
        end
      end

      protected

      # Start a benchmark run and set up the environment
      def start!
        @start_time = Time.now.to_i
        say_configuration
        configure_benchmark_run
        run_cleanup_with_retention_policy
      end

      # Output configuration information
      def say_configuration
        return unless options.verbose?
        shell.say
        shell.say "| on branch '#{git_client.current_branch}', and #{options.compare_with_branch ? "compare with branch: '#{options.compare_with_branch}', and " : ""}Runtime: #{options.humanized_runtime} and assertions: #{options.assert? || "skip"}", :cyan
        shell.say "| Timestamp #{@start_time}", :cyan

        # Terminal capability detection and display
        term = ENV["TERM"] || "not set"
        lang = ENV["LANG"] || "not set"
        no_color = ENV["NO_COLOR"] || "not set"
        stdout_tty = $stdout.tty?

        # Check for Unicode support
        term_unicode = (term.include?("xterm") || term.include?("256color") ||
                        lang.include?("UTF") || lang.include?("utf")) ? "likely" : "unlikely"
        # Check for color support
        term_color = if no_color != "not set"
          "disabled by env"
        elsif !stdout_tty
          "disabled (not a TTY)"
        else
          (term.include?("color") || term == "xterm") ? "likely" : "unlikely"
        end

        shell.say "| Display: " +
          "#{options.classic_style? ? "classic style" : "modern style"}, " +
          "Unicode: #{options.ascii_only? ? "disabled by flag" : term_unicode} [TERM=#{term}, LANG=#{lang}], " +
          "Color: #{options.no_color? ? "disabled by flag" : term_color} [NO_COLOR=#{(no_color == "not set") ? "not set" : "set"}, TTY=#{stdout_tty}]", :cyan

        # Display progress bar information
        shell.say "| Progress bar: #{options.test_warm_up}s warmup + #{options.test_time}s runtime per test", :cyan
        shell.say
      end

      # Configure the benchmark environment
      def configure_benchmark_run
        expanded_setup_file_path = File.expand_path(options.setup_file_path, Dir.pwd)
        expanded_tests_path = File.expand_path(options.tests_path, Dir.pwd)
        test_files = Dir.glob(File.join(expanded_tests_path, "*.rb"))

        require expanded_setup_file_path
        test_files.each { |file| require file }
      end
    end
  end
end
