# frozen_string_literal: true

module Awfy
  module Runners
    module Parallel
      # ForkedRunner runs each benchmark group in parallel by forking a new process
      # for each group. This allows for true parallelism on multi-core systems
      # as each process has its own Global Interpreter Lock (GIL).
      # Ideal for CPU-bound tasks that can benefit from multiple cores.
      class ForkedRunner < Awfy::Runners::Base
        SUCCESS = "SUCCESS"
        ERROR_PREFIX = "ERROR: "

        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          say "Running group '#{group.name}' in forked process" if verbose?

          error = wait_for_child(*_execute_group_in_fork(group, &block))

          if error
            say_error "Error in forked process:"
            say_error error
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

          # Fork a process for each group, then wait for all of them
          children = @suite.groups.to_h do |group|
            say "Running group '#{group.name}' in forked process" if verbose?
            [group.name, _execute_group_in_fork(group, &block)]
          end

          errors = {}
          children.each do |name, (pid, read_pipe)|
            error = wait_for_child(pid, read_pipe)
            if error
              errors[name] = error
              say_error "Error in forked process for group '#{name}':"
              say_error error
            elsif verbose?
              say "Group '#{name}' completed successfully"
            end
          end

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
              write_pipe.write(SUCCESS)
            rescue Exception => e # rubocop:disable Lint/RescueException -- report every failure to the parent
              write_pipe.write("#{ERROR_PREFIX}#{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}")
            ensure
              write_pipe.close
              exit!(0) # Make sure child exits without running any cleanup hooks
            end
          end

          # Parent process
          write_pipe.close
          [pid, read_pipe]
        end

        # Reads the child's report and reaps it.
        # @return [String, nil] The error to report, or nil when the job succeeded
        def wait_for_child(pid, read_pipe)
          result = read_pipe.read
          read_pipe.close
          _, status = Process.waitpid2(pid)

          if result.start_with?(ERROR_PREFIX)
            result.delete_prefix(ERROR_PREFIX)
          elsif result != SUCCESS || !status.success?
            "Forked process exited with exit status #{status.exitstatus.inspect} without reporting a result"
          end
        end
      end
    end
  end
end
