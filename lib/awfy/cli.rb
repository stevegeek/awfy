# frozen_string_literal: true

module Awfy
  class CLI < Thor
    include Thor::Actions

    def self.exit_on_failure? = true

    # Output formatting

    class_option :list, type: :boolean, desc: "Display output in list format instead of table", default: false
    # class_option :classic_style, type: :boolean, desc: "Use classic table style instead of modern style", default: false
    # class_option :ascii_only, type: :boolean, desc: "Use only ASCII characters (no Unicode)", default: false
    # class_option :no_color, type: :boolean, desc: "Disable colored output", default: false

    desc "list [GROUP]", "List all tests in a group"
    def list(group_name = nil)
      # List command always uses single run runner
      shell = Thor::Shell::Basic.new
      git_client = GitClient.new(path: Dir.pwd)
      results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
      session = Awfy::Session.new(shell:, config:, git_client:, results_store:)
      suite = Suites::Loader.new(session:).load
      result_manager = Awfy::ResultManager.new(session:)
      unless suite.tests?
        say_error "Test suite (in '#{config.tests_path}') has no tests defined..."
        exit(1)
      end
      Runners.immediate(suite:, session:).run(group_name) do |group|
        Commands::List.new(session:, group:, benchmarker: Benchmarker.new(session:, result_manager:))
      end
    end
  end
end
