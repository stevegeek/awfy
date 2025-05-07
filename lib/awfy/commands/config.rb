# frozen_string_literal: true

module Awfy
  module Commands
    # Command for managing configuration settings
    class Config < Base
      def inspect(location = nil)
        location_to_inspect = location || "current"
        config_loader = ConfigLoader.new(tests_path: @session.config.tests_path)

        # Try to parse as ConfigLocation enum
        begin
          location_enum = ConfigLocation[location_to_inspect]
        rescue KeyError
          # If not a valid ConfigLocation, try as a file path
          location_enum = location_to_inspect
        end

        # Get config file path
        config_path = config_loader.path_for(location_enum)

        if config_loader.exists?(location_enum)
          config_data = config_loader.load(location_enum)

          @session.shell.say("Configuration at #{config_path}:")
          format_and_display_config(config_data)
        else
          @session.shell.say("No configuration file found at #{config_path}")

          # Show what would be saved if a save command were issued
          @session.shell.say("\nIf saved, would create with these settings:")
          format_and_display_config(@session.config.to_h)
        end
      end

      def save(location = nil)
        location_to_save = location || "current"
        config_loader = ConfigLoader.new(tests_path: @session.config.tests_path)

        # Try to parse as ConfigLocation enum
        begin
          location_enum = ConfigLocation[location_to_save]
        rescue KeyError
          # If not a valid ConfigLocation, try as a file path
          location_enum = location_to_save
        end

        # Get current config as hash and save it
        config_hash = @session.config.to_h
        saved_path = config_loader.save(config_hash, location_enum)

        @session.shell.say("Configuration saved to: #{saved_path}")
      end

      private

      def format_and_display_config(config_data)
        max_key_length = config_data.keys.map { |k| k.to_s.length }.max

        config_data.sort.each do |key, value|
          @session.shell.say("#{key.to_s.ljust(max_key_length)} : #{format_value(value)}")
        end
      end

      def format_value(value)
        case value
        when Hash
          value.inspect
        when Array
          value.inspect
        when Symbol
          ":#{value}\n"
        else
          "#{value}\n"
        end
      end
    end
  end
end
