# frozen_string_literal: true

module Awfy
  module CLICommands
    class YJITStats < Base
      default_command :start

      desc "start [GROUP] [REPORT] [TEST]", "Run YJIT stats"
      def start(group = nil, report = nil, test = nil)
        if config.runtime == "mri"
          shell.say_error_and_exit "Must run with YJIT runtime (if 'both' is selected the command only runs with yjit)"
        end

        Commands::YJITStats.new(session:, group_names: group ? [group] : nil, report_name: report, test_name: test).run
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
