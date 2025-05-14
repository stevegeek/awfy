# frozen_string_literal: true

require "test_helper"

module Awfy
  module Views
    class TestTimedProgressBar < Minitest::Test
      def setup
        @shell = Awfy::Shell.new(config: Config.new)
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
        progress_bar = TimedProgressBar.new(
          shell: @shell,
          total_benchmarks: @total_benchmarks,
          warmup_time: @warmup_time,
          test_time: @test_time,
          title: "Test Progress"
        )

        # Start and stop are the key lifecycle methods
        progress_bar.start
        # Sleep briefly to let the progress bar update at least once
        sleep 0.6
        assert_equal 33, progress_bar.stop
      end

      def test_timed_progress_bar_lifecycle_with_complete
        progress_bar = TimedProgressBar.new(
          shell: @shell,
          total_benchmarks: @total_benchmarks,
          warmup_time: @warmup_time,
          test_time: @test_time,
          title: "Test Progress"
        )

        # Start and stop are the key lifecycle methods
        progress_bar.start
        # Sleep briefly to let the progress bar update at least once
        sleep 0.6
        assert_equal 100, progress_bar.stop(complete: true)
      end
    end
  end
end
