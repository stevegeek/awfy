# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestRunnerTypes < Minitest::Test
    def test_immediate_constant
      assert_equal "immediate", RunnerTypes::IMMEDIATE.value
      assert_instance_of RunnerTypes, RunnerTypes::IMMEDIATE
    end

    def test_spawn_constant
      assert_equal "spawn", RunnerTypes::SPAWN.value
      assert_instance_of RunnerTypes, RunnerTypes::SPAWN
    end

    def test_thread_constant
      assert_equal "thread", RunnerTypes::THREAD.value
      assert_instance_of RunnerTypes, RunnerTypes::THREAD
    end

    def test_forked_constant
      assert_equal "forked", RunnerTypes::FORKED.value
      assert_instance_of RunnerTypes, RunnerTypes::FORKED
    end

    def test_branch_comparison_constant
      assert_equal "branch_comparison", RunnerTypes::BRANCH_COMPARISON.value
      assert_instance_of RunnerTypes, RunnerTypes::BRANCH_COMPARISON
    end

    def test_commit_range_constant
      assert_equal "commit_range", RunnerTypes::COMMIT_RANGE.value
      assert_instance_of RunnerTypes, RunnerTypes::COMMIT_RANGE
    end

    def test_to_s_returns_value
      assert_equal "immediate", RunnerTypes::IMMEDIATE.to_s
      assert_equal "spawn", RunnerTypes::SPAWN.to_s
      assert_equal "thread", RunnerTypes::THREAD.to_s
    end

    def test_parallel_predicate_for_parallel_runners
      assert RunnerTypes::THREAD.parallel?
      assert RunnerTypes::FORKED.parallel?
    end

    def test_parallel_predicate_for_sequential_runners
      refute RunnerTypes::IMMEDIATE.parallel?
      refute RunnerTypes::SPAWN.parallel?
      refute RunnerTypes::BRANCH_COMPARISON.parallel?
      refute RunnerTypes::COMMIT_RANGE.parallel?
    end

    def test_sequential_predicate_for_sequential_runners
      assert RunnerTypes::IMMEDIATE.sequential?
      assert RunnerTypes::SPAWN.sequential?
      assert RunnerTypes::BRANCH_COMPARISON.sequential?
      assert RunnerTypes::COMMIT_RANGE.sequential?
    end

    def test_sequential_predicate_for_parallel_runners
      refute RunnerTypes::THREAD.sequential?
      refute RunnerTypes::FORKED.sequential?
    end

    def test_all_runner_types_have_unique_values
      values = [
        RunnerTypes::IMMEDIATE.value,
        RunnerTypes::SPAWN.value,
        RunnerTypes::THREAD.value,
        RunnerTypes::FORKED.value,
        RunnerTypes::BRANCH_COMPARISON.value,
        RunnerTypes::COMMIT_RANGE.value
      ]
      assert_equal values.uniq.size, values.size
    end

    def test_can_index_by_string
      assert_equal RunnerTypes::IMMEDIATE, RunnerTypes["immediate"]
      assert_equal RunnerTypes::SPAWN, RunnerTypes["spawn"]
      assert_equal RunnerTypes::THREAD, RunnerTypes["thread"]
    end

    def test_parallel_and_sequential_are_mutually_exclusive
      [
        RunnerTypes::IMMEDIATE,
        RunnerTypes::SPAWN,
        RunnerTypes::THREAD,
        RunnerTypes::FORKED,
        RunnerTypes::BRANCH_COMPARISON,
        RunnerTypes::COMMIT_RANGE
      ].each do |runner_type|
        # Each runner type should be either parallel XOR sequential, not both
        assert_equal 1, [runner_type.parallel?, runner_type.sequential?].count(true),
          "#{runner_type} should be either parallel or sequential, not both or neither"
      end
    end

    def test_runner_types_are_comparable
      assert_equal RunnerTypes::IMMEDIATE, RunnerTypes::IMMEDIATE
      refute_equal RunnerTypes::IMMEDIATE, RunnerTypes::SPAWN
    end
  end
end
