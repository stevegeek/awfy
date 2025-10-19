# frozen_string_literal: true

module Awfy
  module CLICommands
    class Profile < Base
      default_command :start

      desc "start [GROUP] [REPORT] [TEST]", "Run CPU profiling"
      def start(group = nil, report = nil, test = nil)
        Commands::Profile.new(session:, group_names: group ? [group] : nil, report_name: report, test_name: test).run
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
