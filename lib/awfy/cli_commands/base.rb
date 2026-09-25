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
        # Use target_repo_path if specified, otherwise use current directory
        repo_path = config.target_repo_path || Dir.pwd
        git_client = GitClient.new(path: repo_path)
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
        # Command-specific options (run/compare) are not Config props. --store names the
        # store file itself; the SQLite store appends ".db" to storage_name. Explicit, so
        # no .awfy.json can redirect it.
        store = thor_opts[:store]
        # Fully qualified: this file is nested under CLICommands, which also has a Config
        # (Thor) class, so a bare `Config` here would resolve to that class instead.
        thor_opts = thor_opts.slice(*Awfy::Config.literal_properties.map(&:name))
        explicit_opts = {}
        if store
          sqlite = thor_opts[:storage_backend].to_s == StoreAliases::SQLite.value
          explicit_opts[:storage_name] = sqlite ? store.delete_suffix(".db") : store
          # storage_name above is only correct for the backend named here; an .awfy.json
          # that redirected storage_backend alone would then pair the wrong backend with a
          # storage_name computed for the other one. Explicit, so it wins too.
          explicit_opts[:storage_backend] = thor_opts[:storage_backend]
        end
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
