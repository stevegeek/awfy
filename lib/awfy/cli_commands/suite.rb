# frozen_string_literal: true

module Awfy
  module CLICommands
    class Suite < Base
      desc "list [GROUPS...]", "List all tests in specified groups (if none provided, lists all)"
      def list(*group_names)
        Commands::Suite.new(session:, group_names:).list
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end

      desc "debug [GROUPS...]", "Run tests in specified groups (if none provided, runs all)"
      def debug(*group_names)
        Commands::Suite.new(session:, group_names:).run
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
