# frozen_string_literal: true

module Awfy
  module CLICommands
    class Memory < Base
      default_command :start

      desc "start [GROUP] [REPORT] [TEST]", "Run memory profiling. Can generate summary across implementations, runtimes and branches."
      def start(group = nil, report = nil, test = nil)
        Commands::Memory.new(session:, group_names: group ? [group] : nil, report_name: report, test_name: test).run
      rescue Errors::SuiteError, Errors::NoBaselineError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
