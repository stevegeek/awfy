# frozen_string_literal: true

# With Zeitwerk autoloading, we don't need to explicitly require files

module Awfy
  module Runners
    def create(suite:, session:)
      if session.config.commit_range
        commit_range(suite:, session:)
      elsif session.config.compare_with_branch
        on_branches(suite:, session:)
      else
        case session.config.runner
        when "forked"
          forked(suite:, session:)
        when "spawn"
          spawn(suite:, session:)
        when "fiber"
          fiber(suite:, session:)
        when "thread"
          thread(suite:, session:)
        else # default to immediate
          immediate(suite:, session:)
        end
      end
    end

    def immediate(suite:, session:)
      ImmediateRunner.new(suite:, session:)
    end

    def forked(suite:, session:)
      ForkedRunner.new(suite:, session:)
    end

    def spawn(suite:, session:)
      SpawnRunner.new(suite:, session:)
    end

    def fiber(suite:, session:)
      FiberRunner.new(suite:, session:)
    end

    def thread(suite:, session:)
      ThreadRunner.new(suite:, session:)
    end

    def on_branches(suite:, session:)
      BranchComparisonRunner.new(suite:, session:)
    end

    def commit_range(suite:, session:)
      CommitRangeRunner.new(suite:, session:)
    end

    module_function :create, :immediate, :forked, :spawn, :fiber, :thread, :on_branches, :commit_range
  end
end
