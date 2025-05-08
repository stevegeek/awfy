# frozen_string_literal: true

module Awfy
  module Runners
    # Factory method to create a runner based on configuration
    def create(suite:, session:)
      runner_type = if session.config.commit_range
        RunnerTypes::COMMIT_RANGE
      elsif session.config.compare_with_branch
        RunnerTypes::BRANCH_COMPARISON
      else
        config.runner
      end

      create_runner(runner_type, suite: suite, session: session)
    end

    # Create a runner of the specified type
    def create_runner(runner_type, suite:, session:)
      case runner_type
      when RunnerTypes::IMMEDIATE
        immediate(suite:, session:)
      when RunnerTypes::SPAWN
        spawn(suite:, session:)
      when RunnerTypes::THREAD
        thread(suite:, session:)
      when RunnerTypes::FORKED
        forked(suite:, session:)
      when RunnerTypes::BRANCH_COMPARISON
        on_branches(suite:, session:)
      when RunnerTypes::COMMIT_RANGE
        commit_range(suite:, session:)
      else
        raise ArgumentError, "Unknown runner type: #{self}"
      end
    end

    # Create a runner that executes benchmarks in the current process
    def immediate(suite:, session:)
      Runners::Sequential::ImmediateRunner.new(suite:, session:)
    end

    # Create a runner that executes benchmarks in forked processes in parallel
    def forked(suite:, session:)
      Runners::Parallel::ForkedRunner.new(suite:, session:)
    end

    # Create a runner that executes benchmarks by spawning new processes
    def spawn(suite:, session:)
      Runners::Sequential::SpawnRunner.new(suite:, session:)
    end

    # Create a runner that executes benchmarks in threads concurrently
    def thread(suite:, session:)
      Runners::Parallel::ThreadRunner.new(suite:, session:)
    end

    # Runners for git operations
    def on_branches(suite:, session:)
      Runners::Sequential::BranchComparisonRunner.new(suite:, session:)
    end

    def commit_range(suite:, session:)
      Runners::Sequential::CommitRangeRunner.new(suite:, session:)
    end

    module_function :create, :create_runner, :immediate, :forked, :spawn, :thread, :on_branches, :commit_range
  end
end
