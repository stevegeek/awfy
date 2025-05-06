# frozen_string_literal: true

module Awfy
  class CLI < Thor
    include Thor::Actions

    def self.exit_on_failure? = true

    desc "list [GROUP]", "List all tests in a group"
    option :table_format, type: :boolean, desc: "Display output in table format", default: false
    def list(group_name = nil)
      # List command always uses single run runner
      shell = Thor::Shell::Basic.new
      git_client = GitClient.new(path: Dir.pwd)
      results_store = Stores.create(config.storage_backend, config.storage_name, config.current_retention_policy)
      session = Awfy::Session.new(shell:, config:, git_client:, results_store:)
      suite = Suites::Loader.new(session:).load
      unless suite.tests?
        say_error "Test suite (in '#{config.tests_path}') has no tests defined..."
        exit(1)
      end
      Runners.single(suite:, session:).run(group_name) do |group|
        Commands::List.new(session:, group:, benchmarker: Benchmarker.new(session:, result_manager: ResultManager.new)).list
      end
    end
  end
end
