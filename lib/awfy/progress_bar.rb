# frozen_string_literal: true

require "ruby-progressbar"

module Awfy
  # ProgressBar class to display benchmark progress
  #
  # This class provides a progress bar visualization for benchmark runs.
  # It estimates total runtime based on the number of benchmarks and their
  # expected runtime, then animates progress during execution.
  class ProgressBar
    def initialize(shell, total_benchmarks, warmup_time, test_time, title: "Running Benchmarks", ascii_only: false)
      @shell = shell
      @total_benchmarks = total_benchmarks
      @ascii_only = ascii_only

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

      # Use instance variable for ascii_only flag
      # Fall back to environment check if not specified
      term = ENV["TERM"] || ""
      lang = ENV["LANG"] || ""
      detected_unicode = term.include?("xterm") || term.include?("256color") ||
        lang.include?("UTF") || lang.include?("utf")

      use_unicode = @ascii_only ? false : detected_unicode

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
