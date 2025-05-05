# frozen_string_literal: true

module Awfy
  module Runners
    # SingleRunRunner is the simplest runner implementation that runs benchmarks
    # in the current branch/environment without any process isolation or git operations
    class SingleRunRunner < Base
      # Execute a benchmark run in the current git state and environment
      # @param group [String, nil] Optional group name to run
      # @yield [Group] Yields the group being run to the block
      # @return [void]
      def run(group = nil, &block)
        # Initialize the environment
        start!

        if group
          run_group(group, &block)
        else
          run_groups(&block)
        end
      end

      # Run a specific benchmark command in the current process
      # This is useful for CLI commands to execute a specific benchmark
      # @param command_class [Class] The command class to execute
      # @param group_name [String, nil] Optional group name to run
      # @param report_name [String, nil] Optional report name to run
      # @param test_name [String, nil] Optional test name to run
      # @return [Object] The result from running the command
      def run_command(command_class, group_name = nil, report_name = nil, test_name = nil)
        # Initialize the environment
        start!

        # Create and run the command
        command = command_class.new(suite, shell, git_client, options)
        command.run(group_name, report_name, test_name)
      end
    end
  end
end
