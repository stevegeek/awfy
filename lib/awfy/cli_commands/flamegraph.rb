# frozen_string_literal: true

module Awfy
  module CLICommands
    class Flamegraph < Base
      desc "generate GROUP REPORT TEST", "Run flamegraph profiling"
      def generate(group, report, test)
        Commands::Flamegraph.new(session:, group_names: [group], report_name: report, test_name: test).run
      rescue Errors::SuiteError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
