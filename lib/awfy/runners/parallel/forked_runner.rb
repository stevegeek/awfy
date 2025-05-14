# frozen_string_literal: true

module Awfy
  module Runners
    module Parallel
      # ForkedRunner runs each benchmark group in parallel by forking a new process
      # for each group. This allows for true parallelism on multi-core systems
      # as each process has its own Global Interpreter Lock (GIL).
      # Ideal for CPU-bound tasks that can benefit from multiple cores.
      class ForkedRunner < Awfy::Runners::Base
        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          say "Running group '#{group.name}' in forked process" if verbose?

          # Execute the group in a forked process
          pid, read_pipe = _execute_group_in_fork(group, &block)

          # Read result from pipe
          result = read_pipe.read
          read_pipe.close

          # Wait for child to finish
          Process.waitpid(pid)

          # Check result
          if result.start_with?("ERROR")
            say_error "Error in forked process:"
            say_error result.sub("ERROR: ", "")
            raise "Benchmark failed in forked process"
          end

          say "Group '#{group.name}' completed successfully" if verbose?
        end

        # Run all benchmark groups in parallel
        def run(group_name = nil, &block)
          start!

          # Run a single group if specified
          if group_name
            group = @suite.find_group(group_name)
            return run_group(group, &block)
          end

          # Run multiple groups in parallel using fork
          processes = {}
          pipes = {}

          # Fork a process for each group
          @suite.groups.each do |group|
            say "Running group '#{group.name}' in forked process" if verbose?

            # Execute the group in a forked process
            pid, read_pipe = _execute_group_in_fork(group, &block)

            # Store process information
            processes[group.name] = pid
            pipes[group.name] = read_pipe
          end

          # Check results from all processes
          errors = {}

          # Wait for all processes to complete and collect results
          processes.each do |name, pid|
            # Read result from the pipe
            result = pipes[name].read
            pipes[name].close

            # Wait for the process to finish
            Process.waitpid(pid)

            # Check for errors
            if result.start_with?("ERROR")
              errors[name] = result.sub("ERROR: ", "")
              say_error "Error in forked process for group '#{name}':"
              say_error errors[name]
            elsif verbose?
              say "Group '#{name}' completed successfully"
            end
          end

          # Report errors if any
          unless errors.empty?
            raise "Benchmark failed in one or more forked processes"
          end
        end

        private

        # Execute a benchmark group in a forked process
        # @param group [Suites::Group] The group to execute
        # @yield [group] The block that creates and returns the job to execute
        # @return [Array<Integer, IO>] The process ID and read pipe
        def _execute_group_in_fork(group)
          read_pipe, write_pipe = IO.pipe

          pid = Process.fork do
            # Child process
            read_pipe.close

            begin
              # Execute the benchmark job
              job = yield group
              job.call

              # Signal success
              write_pipe.write("SUCCESS")
            rescue => e
              # Write error to pipe
              write_pipe.write("ERROR: #{e.message}\n#{e.backtrace.join("\n")}")
            ensure
              write_pipe.close
              exit!(0) # Make sure child exits without running any cleanup hooks
            end
          end

          # Parent process
          write_pipe.close
          [pid, read_pipe]
        end
      end
    end
  end
end
