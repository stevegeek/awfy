# frozen_string_literal: true

module Awfy
  module Runners
    module Parallel
      # ThreadRunner runs each benchmark group in a separate thread within the
      # same process. Due to Ruby's Global Interpreter Lock (GIL), only one
      # thread can execute Ruby code at a time, limiting true parallelism for
      # CPU-bound tasks.
      # Best suited for I/O-bound tasks where threads can perform work while
      # others are waiting for I/O, or for tasks involving C extensions that
      # release the GIL.
      class ThreadRunner < Awfy::Runners::Base
        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          errors = {}
          thread = execute_in_thread(errors, group, &block)
          thread.join

          error = errors[group.name]
          if error
            say_error "Error in Thread:"
            say_error "#{error.message}\n#{error.backtrace.join("\n")}"
            raise "Benchmark failed in Thread"
          end

          say "Group '#{group.name}' completed successfully" if verbose?
        end

        def run(group_name = nil, &block)
          start!

          if group_name
            group = @suite.find_group(group_name)
            return run_group(group, &block)
          end

          threads = {}
          errors = {}

          @suite.groups.each do |group|
            threads[group.name] = execute_in_thread(errors, group, &block)
          end

          # Wait for all threads to finish
          threads.each_value(&:join)

          errors.each do |name, error|
            say_error "Error in Thread for group '#{name}':"
            say_error "#{error.message}\n#{error.backtrace.join("\n")}"
          end

          raise "Benchmark failed in one or more Threads" unless errors.empty?

          @suite.groups.each do |group|
            say "Group '#{group.name}' completed successfully" if verbose?
          end
        end

        private

        def execute_in_thread(errors, group)
          say "Running group '#{group.name}' in Thread" if verbose?
          Thread.new do
            job = yield group
            job.call
          rescue => e
            errors[group.name] = e
          end
        end
      end
    end
  end
end
