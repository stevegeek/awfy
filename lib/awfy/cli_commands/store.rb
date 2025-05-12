# frozen_string_literal: true

module Awfy
  module CLICommands
    class Store < Base
      desc "clean", "Clean up benchmark results based on retention policy"
      def clean
        Commands::Store.new(session:).clean
      end
    end
  end
end
