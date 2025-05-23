# frozen_string_literal: true

require "ruby-progressbar"

module Awfy
  module Views
    # TimedProgressBar class to display benchmark progress based on time estimation
    #
    # This class provides a progress bar visualization for benchmark runs.
    # It estimates total runtime based on the number of benchmarks and their
    # expected runtime, then animates progress during execution.
    class TimedProgressBar
      extend Literal::Properties

      prop :shell, Awfy::Shell
      prop :total_benchmarks, Integer
      prop :warmup_time, Float
      prop :test_time, Float
      prop :title, String, default: "Running"

      def after_initialize
        @start_time = nil
        @thread = nil
        @progressbar = nil
        @running = false
        @percent_complete = 0
      end

      def say(...) = @shell.say(...)

      # Start the progress bar
      def start
        @start_time = Time.now

        # Set progress marks based on terminal capabilities
        progress_mark = @shell.unicode_supported? ? "█" : "#"
        remainder_mark = @shell.unicode_supported? ? "░" : "-"

        @progressbar = ::ProgressBar.create(
          title: @title,
          total: 100,  # Using percentage
          format: "%t %c/%C |%w>%i| %p%% %a %e",
          output: @shell.mute? ? StringIO.new : $stdout,
          length: 80,
          progress_mark: progress_mark,
          remainder_mark: remainder_mark
        )

        # Start a thread to update the progress
        @running = true
        @thread = Thread.new do
          while @running
            update_progress
            sleep 0.5  # Update every half second
          end
        end
      end

      # Stop the progress bar
      def stop(complete: false)
        return unless @running

        @running = false
        @thread&.join(1) # Wait up to 1 second for thread to finish

        # Ensure progress reaches 100%
        if @progressbar && complete
          @progressbar.finish
          @percent_complete = 100
        end
        @percent_complete
      end

      def estimated_total_time
        # Calculate total estimated time in seconds
        # Each benchmark runs warmup + test time for each item
        @total_benchmarks * (@warmup_time + @test_time)
      end

      private

      # Update progress based on elapsed time
      def update_progress
        return unless @start_time && @progressbar

        total_time = estimated_total_time
        elapsed = Time.now - @start_time
        @percent_complete = [(elapsed / total_time * 100).to_i, 100].min

        # Only update if progress increased
        if @percent_complete > @progressbar.progress
          @progressbar.progress = @percent_complete
        end

        # Stop when complete
        if @percent_complete >= 100
          @running = false
        end
      end
    end
  end
end
