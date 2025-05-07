# frozen_string_literal: true

require "test_helper"

module Awfy
  module Views
    class TestTimedProgressBar < Minitest::Test
      def setup
        @shell = Awfy::Shell.new(config: Config.new)
        @total_benchmarks = 5
        @warmup_time = 1
        @test_time = 2
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
        progress_bar.stop

        # Mainly testing that these operations don't raise exceptions
        assert_equal true, true
      end
    end
  end
end
