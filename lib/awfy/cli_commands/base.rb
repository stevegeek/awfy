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

        thor_opts[:verbose] = VerbosityLevel::MUTE if thor_opts[:quiet]
        thor_opts.delete(:quiet)

        thor_opts[:verbose] = VerbosityLevel::BASIC if thor_opts[:v]
        thor_opts.delete(:v)

        # FIXME: This should be set to be the options set on the CLI by the
        # user not considering the defaults... but still need to work out how to
        # do that.
        explicit_opts = {}
        # Create ConfigLoader with appropriate options
        tests_path = thor_opts[:tests_path] || "./benchmarks/tests"
        setup_file_path = thor_opts[:setup_file_path] || "./benchmarks/setup"
        # Load configuration files with precedence
        # Only explicitly set CLI options take highest precedence
        config_loader = ConfigLoader.new(
          thor_opts,
          explicit_opts,
          tests_path: tests_path,
          setup_file_path: setup_file_path,
          shell: (thor_opts[:verbose] == 3) ? Thor::Shell::Color.new : nil
        )

        @config = config_loader.load_with_precedence
      end
    end
  end
end
