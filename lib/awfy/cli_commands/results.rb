# frozen_string_literal: true

module Awfy
  module CLICommands
    class Results < Base
      desc "list [TYPE]", "List all stored benchmark results (optionally filter by TYPE: ips or memory)"
      def list(type = nil)
        unless type.nil? || ["ips", "memory"].include?(type)
          shell.say_error_and_exit "Error: TYPE must be either 'ips' or 'memory'"
        end

        type_sym = type&.to_sym
        Commands::Results.new(session:, type: type_sym).list
      end

      desc "show GROUP [REPORT] [TYPE]", "Show detailed results for a specific group/report (optionally filter by TYPE: ips or memory)"
      def show(group = nil, report = nil, type = nil)
        unless group
          shell.say_error_and_exit "Error: GROUP name is required\nUsage: awfy results show GROUP [REPORT] [TYPE]"
        end

        unless type.nil? || ["ips", "memory"].include?(type)
          shell.say_error_and_exit "Error: TYPE must be either 'ips' or 'memory'"
        end

        type_sym = type&.to_sym
        Commands::Results.new(
          session:,
          group_names: [group],
          report_name: report,
          type: type_sym
        ).show
      rescue Errors::SuiteError, Errors::NoBaselineError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
