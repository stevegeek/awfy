# frozen_string_literal: true

module Awfy
  module Runners
    # SingleRunRunner is the simplest runner implementation that runs benchmarks
    # in the current branch/environment without any process isolation or git operations
    class ImmediateRunner < Base
      # Execute a benchmark run in the current git state and environment
      def run_group(group, &)
        # Initialize the environment
        start!

        if block_given?
          job = yield group
          job.call
        else
          raise ArgumentError, "No block given to run_group"
        end
      end
    end
  end
end
