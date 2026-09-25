# frozen_string_literal: true

require "test_helper"
require_relative "test_helper" # Ensures ViewTestCase is loaded

module Awfy
  module Views
    class TestTimedProgressBar < ::ViewTestCase
      def setup
        super
        @total_benchmarks = 5
        @warmup_time = 0.1
        @test_time = 0.2
      end

      def test_timed_progress_bar_initialization
        progress_bar = TimedProgressBar.new(
          shell: @shell,
          total_benchmarks: @total_benchmarks,
          warmup_time: @warmup_time,
          test_time: @test_time,
          title: "Test Progress"
        )

        assert_instance_of TimedProgressBar, progress_bar
      end

      def test_timed_progress_bar_lifecycle
        progress_bar = build_with_fake_clock
        progress_bar.start

        # Estimated total is 5 * (0.1 + 0.2) = 1.5s, so 0.5s elapsed is 33%.
        @now = 0.5
        wait_for_percent(progress_bar, 33)

        assert_equal 33, progress_bar.stop
      end

      def test_timed_progress_bar_lifecycle_with_complete
        progress_bar = build_with_fake_clock
        progress_bar.start

        @now = 0.5
        wait_for_percent(progress_bar, 33)

        assert_equal 100, progress_bar.stop(complete: true)
      end

      private

      def build_with_fake_clock
        @now = 0.0
        TimedProgressBar.new(
          shell: @shell,
          total_benchmarks: @total_benchmarks,
          warmup_time: @warmup_time,
          test_time: @test_time,
          title: "Test Progress",
          clock: -> { @now },
          refresh_interval: 0.001
        )
      end

      # Waits for the background thread to apply the fake clock; the deadline only guards a hang.
      def wait_for_percent(progress_bar, percent)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until progress_bar.percent_complete == percent
          flunk "progress stayed at #{progress_bar.percent_complete}%, expected #{percent}%" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          Thread.pass
        end
      end
    end
  end
end
