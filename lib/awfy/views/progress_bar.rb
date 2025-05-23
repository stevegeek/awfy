# frozen_string_literal: true

require "ruby-progressbar"

module Awfy
  module Views
    # Base ProgressBar class for displaying progress bars that are manually incremented
    #
    # This class provides a progress bar visualization that can be manually incremented,
    # making it suitable for tracking progress through a sequence of discrete steps.
    class ProgressBar
      extend Literal::Properties

      prop :shell, Awfy::Shell
      prop :total_benchmarks, Integer
      prop :title, String, default: "Progress"

      def after_initialize
        @current = 0

        # Set progress marks based on terminal capabilities
        progress_mark = @shell.unicode_supported? ? "█" : "#"
        remainder_mark = @shell.unicode_supported? ? "░" : "-"

        @progressbar = ::ProgressBar.create(
          title: @title,
          total: @total_benchmarks,
          format: "%t %c/%C |%w>%i| %p%% %e",
          output: @shell.mute? ? StringIO.new : $stdout,
          length: 80,
          progress_mark: progress_mark,
          remainder_mark: remainder_mark
        )
      end

      def say(...) = @shell.say(...)

      # Increment the progress by a specific amount
      def increment(amount = 1)
        # Calculate new progress but cap it at total
        new_progress = [@current + amount, @total_benchmarks].min
        @current = new_progress
        @progressbar.progress = @current

        # Automatically finish if we've reached the total
        finish if @current >= @total_benchmarks
      end

      # Set the progress to a specific value
      def progress=(value)
        @current = value.clamp(0, @total_benchmarks)
        @progressbar.progress = @current

        # Automatically finish if we've reached the total
        finish if @current >= @total_benchmarks
      end

      # Get the current progress
      def progress
        @current
      end

      # Finish the progress bar (set to 100%)
      def finish
        @progressbar.finish
        @current = @total_benchmarks
      end

      # Whether the progress is complete
      def complete?
        @current >= @total_benchmarks
      end
    end
  end
end
