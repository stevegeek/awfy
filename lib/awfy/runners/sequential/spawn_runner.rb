# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # SpawnRunner runs each benchmark group by spawning a new awfy process
      # This provides maximum isolation between benchmark runs by using separate Ruby processes
      class SpawnRunner < Awfy::Runners::Base
        # Execute a benchmark group by spawning a new awfy process
        def run_group(group, &block)
          # Initialize the environment
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          say "Running group '#{group.name}' in spawned process" if verbose?

          # Get the command instance that will be called
          job = yield group

          # Determine the command type from the job
          command_class = job.class.name.split("::").last.downcase

          # Build the command to run the benchmark in a separate process
          cmd = ["bundle", "exec", "ruby", "-Ilib", "exe/awfy", command_class]

          # Add group name
          cmd << group.name

          #
          #
          # # Run a command in a fresh Ruby process
          # # @param command_type [String] The command type (ips, memory, etc.)
          # # @param group_name [String, nil] Optional group name to run
          # # @param report_name [String, nil] Optional report name to run
          # # @param test_name [String, nil] Optional test name to run
          # # @param extra_options [Hash] Additional command-line options to pass
          # # @return [Boolean] Whether the command succeeded
          # def run_in_fresh_process(command_type, group_name = nil, report_name = nil, test_name = nil, extra_options = {})
          #   # Build the command to run the benchmark in a separate process
          #   cmd = ["ruby", "-r", "./lib/awfy", "exe/awfy", command_type]
          #
          #   # Add group, report, test if provided
          #   cmd << group_name if group_name
          #   cmd << report_name if report_name
          #   cmd << test_name if test_name
          #
          #   # Add standard options
          #   cmd << "--save"   # Always save results for collection
          #   cmd << "--runtime=#{options.runtime}" if options.runtime
          #   cmd << "--test-time=#{options.test_time}" if options.test_time
          #   cmd << "--test-warm-up=#{options.test_warm_up}" if options.test_warm_up
          #   cmd << "--verbose" if options.verbose?
          #   cmd << "--classic-style" if options.classic_style?
          #   cmd << "--ascii-only" if options.ascii_only?
          #   cmd << "--no-color" if options.no_color?
          #
          #   # Add storage options
          #   cmd << "--storage-backend=#{options.storage_backend}" if options.storage_backend
          #   cmd << "--storage-name=#{options.storage_name}" if options.storage_name
          #
          #   # Add any extra options
          #   extra_options.each do |key, value|
          #     if value == true
          #       cmd << "--#{key}"
          #     elsif value != false && !value.nil?
          #       cmd << "--#{key}=#{value}"
          #     end
          #   end
          #
          #   # Execute and capture output
          #   system(*cmd)
          # end
          #

          # Add configuration options from the current session
          cmd << "--storage-backend=#{config.storage_backend}" if config.storage_backend
          cmd << "--storage-name=#{config.storage_name}" if config.storage_name
          cmd << "--verbose" if verbose?

          # Execute and capture output
          say "Executing: #{cmd.join(" ")}" if verbose?

          output = ""

          # Use IO.popen to capture output
          IO.popen(cmd.join(" "), err: [:child, :out]) do |io|
            output = io.read
          end
          status = $?.exitstatus

          if status != 0
            say_error "Error in spawned process (exit code: #{status}):"
            say_error output
            raise "Benchmark failed in spawned process"
          end

          say output unless output.empty?
          say "Group '#{group.name}' completed successfully" if verbose?
        end
      end
    end
  end
end
