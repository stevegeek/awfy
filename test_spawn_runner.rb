#!/usr/bin/env ruby
# Test script to verify spawn runner works with bundle exec awfy

require "bundler/setup"
require_relative "lib/awfy"

# Create a simple benchmark group
config = Awfy::Config.new(
  storage_backend: :memory,
  verbose: true
)

runner = Awfy::Runners.spawn(config)

puts "Testing spawn runner..."
puts "Current directory: #{Dir.pwd}"
puts "awfy executable exists at exe/awfy: #{File.exist?('exe/awfy')}"

# Try to create a simple benchmark
Awfy.configure do |c|
  c.storage_backend = :memory
end

Awfy.benchmark "Test Group" do
  baseline "simple" do
    1 + 1
  end
end

# Use the spawn runner
begin
  runner.run do |group|
    job = Awfy::Jobs::IPS.new(
      group: group,
      config: config,
      verbose: true
    )
    job
  end
  puts "\nSUCCESS: Spawn runner executed successfully!"
rescue => e
  puts "\nERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end