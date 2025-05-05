# frozen_string_literal: true

require "test_helper"

class TestProgressBar < Minitest::Test
  def setup
    @shell = Thor::Shell::Basic.new
    @total_benchmarks = 5
    @warmup_time = 1
    @test_time = 2
  end

  def test_progress_bar_initialization
    progress_bar = Awfy::Views::ProgressBar.new(
      @shell,
      @total_benchmarks,
      @warmup_time,
      @test_time,
      title: "Test Progress"
    )

    assert_instance_of Awfy::Views::ProgressBar, progress_bar
  end

  def test_progress_bar_lifecycle
    progress_bar = Awfy::Views::ProgressBar.new(
      @shell,
      @total_benchmarks,
      @warmup_time,
      @test_time,
      title: "Test Progress"
    )

    # Capture output
    original_stdout = $stdout
    $stdout = StringIO.new

    begin
      progress_bar.start
      # Sleep briefly to let the progress bar update at least once
      sleep 0.6
      progress_bar.stop

      output = $stdout.string
      assert_match(/Test Progress/, output)
    ensure
      $stdout = original_stdout
    end
  end
end