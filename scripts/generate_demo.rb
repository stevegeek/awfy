#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate an asciinema demo video for awfy
#
# Usage:
#   ruby scripts/generate_demo.rb
#
# This will create demo.cast which can be uploaded to asciinema.org

require_relative "cast_generator"

# Change to the project root
Dir.chdir(File.expand_path("..", __dir__))

# Define the demo recording
cast = record_cast(
  width: 120,
  height: 30,
  title: "Awfy - Ruby Benchmark Tool Demo",
  idle_time_limit: 2.0
) do
  comment "Awfy - A CLI tool for running and comparing Ruby benchmarks", pause_after: 1.0
  pause 0.5

  comment "Let's see what benchmark suites are available", pause_after: 1.0
  command "bundle exec awfy suite list", pause_after: 2.0

  pause 1.0
  comment "Run an IPS benchmark on numeric operations", pause_after: 1.0
  command "bundle exec awfy ips start Numerics '#+'", pause_after: 3.0

  pause 1.0
  comment "You can also run benchmarks with different settings", pause_after: 1.0
  command "bundle exec awfy ips start Numerics '#*' --runner=forked", pause_after: 3.0

  pause 1.0
  comment "Check out the full documentation at github.com/stevegeek/awfy", pause_after: 2.0
end

# Generate the cast file
cast.generate("demo.cast")

# Generate gif if agg is available
if system("which agg > /dev/null 2>&1")
  puts "\nGenerating GIF with agg..."

  success = system(
    "agg",
    "--theme", "monokai",
    "--font-size", "14",
    "--fps-cap", "30",
    "--speed", "2.0",
    "--idle-time-limit", "2.0",
    "--last-frame-duration", "3",
    "demo.cast",
    "demo.gif"
  )

  if success
    puts "GIF generated: demo.gif"
    puts "Size: #{File.size("demo.gif") / 1024}KB"
  else
    puts "Failed to generate GIF"
  end
else
  puts "\nNote: Install agg to generate GIF files:"
  puts "  https://github.com/asciinema/agg"
end

puts "\nTo view the demo locally:"
puts "  asciinema play demo.cast"
puts "\nTo upload to asciinema.org:"
puts "  asciinema upload demo.cast"
puts "\nThen add the badge to README.md:"
puts "  [![asciicast](https://asciinema.org/a/XXXXX.svg)](https://asciinema.org/a/XXXXX)"
puts "\nOr embed the GIF directly:"
puts "  ![Demo](demo.gif)"
