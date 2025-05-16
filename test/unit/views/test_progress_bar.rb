# frozen_string_literal: true

require "test_helper"
require_relative "test_helper" # Ensures ViewTestCase is loaded

module Awfy
  module Views
    class TestProgressBar < ::ViewTestCase
      def test_progress_bar_initialization
        progress_bar = ProgressBar.new(
          shell: @shell,
          total_benchmarks: 10,
          title: "Test Progress"
        )

        assert_instance_of ProgressBar, progress_bar
        assert_equal 0, progress_bar.progress
        assert_equal false, progress_bar.complete?
      end

      def test_progress_bar_increment
        progress_bar = ProgressBar.new(
          shell: @shell,
          total_benchmarks: 10,
          title: "Test Progress"
        )

        # Increment by 1
        progress_bar.increment
        assert_equal 1, progress_bar.progress
        assert_equal false, progress_bar.complete?

        # Increment by custom amount
        progress_bar.increment(4)
        assert_equal 5, progress_bar.progress
        assert_equal false, progress_bar.complete?

        # Increment to completion
        progress_bar.increment(5)
        assert_equal 10, progress_bar.progress
        assert_equal true, progress_bar.complete?

        # Increment beyond total should be capped
        progress_bar.progress = 5  # Reset to 5 first
        progress_bar.increment(10) # Try to go to 15
        assert_equal 10, progress_bar.progress
      end

      def test_progress_bar_setting_progress
        progress_bar = ProgressBar.new(
          shell: @shell,
          total_benchmarks: 10,
          title: "Test Progress"
        )

        # Set progress directly
        progress_bar.progress = 5
        assert_equal 5, progress_bar.progress
        assert_equal false, progress_bar.complete?

        # Verify boundaries work
        progress_bar.progress = -5  # Below min
        assert_equal 0, progress_bar.progress

        progress_bar.progress = 15  # Above max
        assert_equal 10, progress_bar.progress
        assert_equal true, progress_bar.complete?
      end

      def test_progress_bar_finish
        progress_bar = ProgressBar.new(
          shell: @shell,
          total_benchmarks: 10,
          title: "Test Progress"
        )

        # First make some progress
        progress_bar.progress = 5

        # Manually finish the progress bar
        progress_bar.finish

        # After finish, it should be at 100%
        assert_equal true, progress_bar.complete?
      end
    end
  end
end
