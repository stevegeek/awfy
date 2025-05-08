# frozen_string_literal: true

module Awfy
  # RunnerType defines the supported runner implementations as an enum
  # This provides type safety and pattern matching support
  class RunnerTypes < Literal::Enum(String)
    # Sequential runners
    IMMEDIATE = new("immediate")
    SPAWN = new("spawn")

    # Parallel runners
    THREAD = new("thread")
    FORKED = new("forked")

    # Special runners for git operations
    BRANCH_COMPARISON = new("branch_comparison")
    COMMIT_RANGE = new("commit_range")

    def to_s
      value
    end

    # Returns whether the runner is a parallel runner
    def parallel?
      [THREAD, FORKED].include?(self)
    end

    # Returns whether the runner is a sequential runner
    def sequential?
      [IMMEDIATE, SPAWN, BRANCH_COMPARISON, COMMIT_RANGE].include?(self)
    end
  end
end
