# frozen_string_literal: true

module Awfy
  # Suite subcommand for managing test suites
  module CLICommands
    class Base < Thor
      include Thor::Actions

      no_commands do
        def invoke_command(command, *args)
          setup_session
          session.say_configuration if config.verbose?(VerbosityLevel::DETAILED)
          super
        end
      end

      private

      attr_reader :shell, :session

      def setup_session
        @shell = Awfy::Shell.new(config:)
        git_client = GitClient.new(path: Dir.pwd)
        results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
        @session = Awfy::Session.new(shell:, config:, git_client:, results_store:)
      end

      def config
        return @config if defined?(@config)
        # Get options from Thor and convert keys to symbols
        thor_opts = options.to_h.transform_keys(&:to_sym)

        # Handle shorthand verbosity flags
        # Convert -v, -vv, -vvv to verbosity levels
        if thor_opts.key?(:v)
          if thor_opts[:vvv]
            thor_opts[:verbose] = VerbosityLevel::DEBUG
          elsif thor_opts[:vv]
            thor_opts[:verbose] = VerbosityLevel::DETAILED
          elsif thor_opts[:v]
            thor_opts[:verbose] = VerbosityLevel::BASIC
          end
          
          # Remove the shorthand flags as they are not Config properties
          thor_opts.delete(:v)
          thor_opts.delete(:vv)
          thor_opts.delete(:vvv)
        end

        # Create ConfigLoader with appropriate options
        tests_path = thor_opts[:tests_path] || "./benchmarks/tests"
        setup_file_path = thor_opts[:setup_file_path] || "./benchmarks/setup"

        # Load configuration files with precedence
        config_loader = ConfigLoader.new(
          tests_path: tests_path,
          setup_file_path: setup_file_path
        )
        file_config = config_loader.load_with_precedence

        # Merge file config with CLI options (CLI options take highest precedence)
        merged_config = file_config.merge(thor_opts)

        # Create the Config data object with merged options
        @config = Awfy::Config.new(**merged_config)
      end
    end
  end
end
