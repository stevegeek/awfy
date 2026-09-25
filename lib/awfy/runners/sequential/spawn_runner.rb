# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # SpawnRunner runs each benchmark group by spawning a new awfy process
      # This provides maximum isolation between benchmark runs by using separate Ruby processes
      class SpawnRunner < Awfy::Runners::Base
        # Execute a benchmark group by spawning a new awfy process
        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          say "Running group '#{group.name}' in spawned process" if verbose?

          # The job is not called here; it only tells the child which command to run.
          job = yield group
          run_in_child_process(ChildCommand.for_job(job, group_name: group.name, config:))
          say "Group '#{group.name}' completed successfully" if verbose?
        end
      end
    end
  end
end
