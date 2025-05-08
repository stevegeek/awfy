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
