# frozen_string_literal: true

module Awfy
  module Commands
    # Command for managing configuration settings
    class Config < Base
      def inspect(location = nil)
        config_loader = ConfigLoader.new(
          {},
          {},
          tests_path: config.tests_path,
          shell: verbose?(VerbosityLevel::DEBUG) && session.shell
        )
        location_enum = parse_location(location)

        # Get config file path
        config_path = config_loader.path_for(location_enum)
        config_view = Views::ConfigView.new(session: session)

        if config_loader.exists?(location_enum)
          config_data = config_loader.load(location_enum)

          say("Configuration at #{config_path}:")
          config_view.format_and_display_config(config_data, nil)
        else
          say("No configuration file found at #{config_path}")

          # Show what would be saved if a save command were issued
          say("\nIf saved, would create with these settings:")
          config_view.format_and_display_config(config.to_h, nil)
        end
      end

      def save(location = nil)
        config_loader = ConfigLoader.new(
          {},
          {},
          tests_path: config.tests_path,
          shell: verbose?(VerbosityLevel::DEBUG) && session.shell
        )
        location_enum = parse_location(location)

        # Get current config as hash and save it
        config_hash = config.to_h
        saved_path = config_loader.save(config_hash, location_enum)

        config_view = Views::ConfigView.new(session: session)
        config_view.format_and_display_config(config_hash, nil)

        say("Configuration saved to: #{saved_path}")
      end

      private

      def parse_location(location)
        location_to_inspect = location || "current"
        # Try to parse as ConfigLocation enum
        begin
          ConfigLocation[location_to_inspect]
        rescue KeyError
          # If not a valid ConfigLocation, try as a file path
          location_to_inspect
        end
      end
    end
  end
end
