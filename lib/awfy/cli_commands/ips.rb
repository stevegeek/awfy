# frozen_string_literal: true

module Awfy
  module CLICommands
    class IPS < Base
      default_command :start

      desc "start [GROUP] [REPORT] [TEST]", "Run IPS benchmarks. Can generate summary across implementations, runtimes and branches."
      def start(group: nil, report: nil, test: nil)
        Commands::IPS.new(session:, group:, report:, test:).run
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
