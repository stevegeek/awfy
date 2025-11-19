#!/usr/bin/env ruby
# frozen_string_literal: true

require "pty"
require "json"
require "io/console"

# Generates asciinema cast files by running real commands and capturing output
class CastGenerator
  def initialize(width: 120, height: 30, title: nil, idle_time_limit: nil)
    @width = width
    @height = height
    @title = title
    @idle_time_limit = idle_time_limit
    @events = []
    @start_time = nil
  end

  # Define a command to run with optional typing simulation and delays
  def command(cmd, type_speed: nil, pause_before: 0, pause_after: 1.5)
    sleep(pause_before) if pause_before > 0

    # Simulate typing if requested
    if type_speed && type_speed > 0
      simulate_typing(cmd, type_speed)
    else
      record_output(cmd)
    end

    # Execute the command and capture output
    execute_command(cmd)

    sleep(pause_after) if pause_after > 0
  end

  # Add a pause without executing anything
  def pause(duration)
    sleep(duration)
  end

  # Add raw output without executing a command (useful for comments)
  def comment(text, pause_after: 0.5)
    record_output("# #{text}\r\n")
    sleep(pause_after)
  end

  # Generate the cast file
  def generate(output_file)
    # Write header
    header = {
      version: 2,
      width: @width,
      height: @height,
      timestamp: @start_time.to_i
    }
    header[:title] = @title if @title
    header[:idle_time_limit] = @idle_time_limit if @idle_time_limit

    File.open(output_file, "w") do |f|
      f.puts header.to_json

      @events.each do |timestamp, type, data|
        f.puts [timestamp, type, data].to_json
      end
    end

    puts "Cast file generated: #{output_file}"
    puts "Events recorded: #{@events.length}"
    puts "Duration: #{format("%.2f", @events.last[0])}s" if @events.any?
  end

  private

  def ensure_started
    @start_time ||= Time.now
  end

  def current_timestamp
    ensure_started
    Time.now - @start_time
  end

  def record_output(data)
    return if data.empty?
    # Ensure valid UTF-8 encoding for JSON
    utf8_data = data.dup.force_encoding("UTF-8")
    # Replace invalid/undefined characters with valid UTF-8
    utf8_data = utf8_data.scrub("?")
    @events << [current_timestamp, "o", utf8_data]
  end

  def simulate_typing(text, chars_per_second)
    delay = 1.0 / chars_per_second
    text.each_char do |char|
      record_output(char)
      sleep(delay)
    end
    record_output("\r\n")
  end

  def execute_command(cmd)
    output_buffer = String.new

    begin
      PTY.spawn({"TERM" => "xterm-256color"}, cmd) do |stdout, stdin, pid|
        stdin.close

        begin
          # Read output in chunks and record with timestamps
          until stdout.eof?
            # Use select with timeout to capture timing accurately
            if IO.select([stdout], nil, nil, 0.1)
              chunk = stdout.read_nonblock(4096)
              record_output(chunk)
              output_buffer << chunk
            end
          end
        rescue Errno::EIO
          # End of output
        rescue IO::WaitReadable
          # Nothing to read
        end

        # Wait for process to complete
        Process.wait(pid)
      end
    rescue PTY::ChildExited
      # Command finished
    rescue Errno::ENOENT => e
      # Command not found
      error_msg = "bash: #{cmd.split.first}: command not found\r\n"
      record_output(error_msg)
    end

    # Add a small delay after command completion
    sleep(0.1)
  end
end

# DSL for defining cast recordings
def record_cast(width: 120, height: 30, title: nil, idle_time_limit: 2.0, &block)
  generator = CastGenerator.new(
    width: width,
    height: height,
    title: title,
    idle_time_limit: idle_time_limit
  )

  generator.instance_eval(&block)
  generator
end
