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

          read_pipe, write_pipe = IO.pipe

          pid = Process.fork do
            # Child process

            read_pipe.close

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

          # Parent process
          write_pipe.close
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
      end
    end
  end
end
