# frozen_string_literal: true

module Awfy
  # Suite subcommand for managing test suites
  class CLICommand < Thor
    include Thor::Actions

    private

    def config
      # Get options from Thor and convert keys to symbols
      thor_opts = options.to_h.transform_keys(&:to_sym)

      # Load configuration files with precedence
      config_loader = ConfigLoader.new
      file_config = config_loader.load_with_precedence

      # Merge file config with CLI options (CLI options take highest precedence)
      merged_config = file_config.merge(thor_opts)

      # Create the Config data object with merged options
      Config.new(**merged_config)
    end
  end
end
