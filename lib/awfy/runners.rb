# frozen_string_literal: true

# With Zeitwerk autoloading, we don't need to explicitly require files

module Awfy
  module Runners
    module_function

    def create(suite, shell, git_client, options)
      if options.commit_range
        commit_range(suite, shell, git_client, options)
      elsif options.compare_with_branch
        on_branches(suite, shell, git_client, options)
      else
        immediate(suite, shell, git_client, options)
      end
    end

    def immediate(suite:, session:)
      ImmediateRunner.new(suite:, session:)
    end

    def on_branches(suite, shell, git_client, options)
      BranchComparisonRunner.new(suite, shell, git_client, options)
    end

    def commit_range(suite, shell, git_client, options)
      CommitRangeRunner.new(suite, shell, git_client, options)
    end
  end
end
