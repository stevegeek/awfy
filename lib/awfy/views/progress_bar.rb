# frozen_string_literal: true

require "ruby-progressbar"

module Awfy
  module Views
    # ProgressBar class to display benchmark progress
    #
    # This class provides a progress bar visualization for benchmark runs.
    # It estimates total runtime based on the number of benchmarks and their
    # expected runtime, then animates progress during execution.
    class ProgressBar
      extend Literal::Properties

      prop :shell, Awfy::Shell
      prop :total_benchmarks, Integer
      prop :warmup_time, Integer
      prop :test_time, Integer
      prop :title, String, default: "Running"
      prop :ascii_only, _Boolean, default: false

      def after_initialize
        @start_time = nil
        @thread = nil
        @progressbar = nil
        @running = false
      end

      def say(...) = @shell.say(...)

      # Start the progress bar
      def start
        @start_time = Time.now

        # Check if shell supports unicode, respecting the ascii_only flag
        use_unicode = !@ascii_only && @shell.unicode_supported?

        # Set proper progress marks based on terminal capabilities
        progress_mark = use_unicode ? "█" : "#"
        remainder_mark = use_unicode ? "░" : "-"

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
      def stop
        return unless @running

        @running = false
        @thread&.join(1) # Wait up to 1 second for thread to finish

        # Ensure progress reaches 100%
        @progressbar.finish if @progressbar
      end

      private

      # Update progress based on elapsed time
      def update_progress
        return unless @start_time && @progressbar

        # Calculate total estimated time in seconds
        # Each benchmark runs warmup + test time for each item
        total_time = @total_benchmarks * (@warmup_time + @test_time)
        elapsed = Time.now - @start_time
        percent_complete = [(elapsed / total_time * 100).to_i, 100].min

        # Only update if progress increased
        if percent_complete > @progressbar.progress
          @progressbar.progress = percent_complete
        end

        # Stop when complete
        if percent_complete >= 100
          @running = false
        end
      end
    end
  end
end
