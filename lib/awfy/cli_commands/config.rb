# frozen_string_literal: true

module Awfy
  module CLICommands
    class Config < Base
      desc "inspect [LOCATION]", "Show current configuration settings"
      def inspect(location = nil)
        Commands::Config.new(session:).inspect(location)
      end

      desc "save [LOCATION]", "Save current configuration to a file"
      def save(location = nil)
        Commands::Config.new(session:).save(location)
      end
    end
  end
end
