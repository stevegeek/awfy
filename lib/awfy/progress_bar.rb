# frozen_string_literal: true

require "ruby-progressbar"

module Awfy
  # ProgressBar class to display benchmark progress
  #
  # This class provides a progress bar visualization for benchmark runs.
  # It estimates total runtime based on the number of benchmarks and their
  # expected runtime, then animates progress during execution.
  class ProgressBar
    def initialize(shell, total_benchmarks, warmup_time, test_time, title: "Running Benchmarks")
      @shell = shell
      @total_benchmarks = total_benchmarks

      # Calculate total estimated time in seconds
      # Each benchmark runs warmup + test time for each item
      @total_time = total_benchmarks * (warmup_time + test_time)

      @title = title
      @start_time = nil
      @thread = nil
      @progressbar = nil
      @running = false
    end

    # Start the progress bar
    def start
      @start_time = Time.now

      @progressbar = ::ProgressBar.create(
        title: @title,
        total: 100,  # Using percentage
        format: "%t: [%B] %p%% %a %e",
        output: @shell.mute? ? StringIO.new : $stdout
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

      elapsed = Time.now - @start_time
      percent_complete = [(elapsed / @total_time * 100).to_i, 100].min

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
