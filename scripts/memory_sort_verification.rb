#!/usr/bin/env ruby
# frozen_string_literal: true

# Test to verify memory benchmark sorting

require "bundler/setup"
require "tmpdir"
require "fileutils"

puts "Testing memory benchmark sorting..."
puts

test_repo = Dir.mktmpdir("awfy_memory_sort_test")

begin
  Dir.chdir(test_repo) do
    # Initialize git repo
    system("git init -q")
    system("git config user.name 'Test User'")
    system("git config user.email 'test@example.com'")

    # Create benchmark structure
    FileUtils.mkdir_p("benchmarks/tests")
    FileUtils.mkdir_p("lib")

    # Create a library that allocates different amounts of memory
    File.write("lib/allocator.rb", <<~RUBY)
      module Allocator
        ARRAY_SIZE = 1000  # Initial size

        def self.allocate_array
          Array.new(ARRAY_SIZE) { "x" * 100 }
        end
      end
    RUBY

    # Setup file
    File.write("benchmarks/setup.rb", <<~RUBY)
      lib_path = File.expand_path("../../lib/allocator.rb", __FILE__)
      Object.send(:remove_const, :Allocator) if defined?(Allocator)
      load lib_path
    RUBY

    # Memory benchmark test
    File.write("benchmarks/tests/memory_test.rb", <<~RUBY)
      Awfy.group "Memory Test" do
        report "Array Allocation" do
          control "baseline" do
            Allocator.allocate_array
          end

          test "variant" do
            Allocator.allocate_array
          end
        end
      end
    RUBY

    # Commit 1: ARRAY_SIZE = 1000 (baseline)
    system("git add -A")
    system("git commit -q -m 'Baseline: ARRAY_SIZE = 1000'")
    commit1 = `git rev-parse HEAD`.strip
    puts "Commit 1 (baseline): #{commit1[0..7]} - ARRAY_SIZE = 1000"

    # Commit 2: ARRAY_SIZE = 500 (half memory - BETTER)
    content = File.read("lib/allocator.rb")
    File.write("lib/allocator.rb", content.gsub("ARRAY_SIZE = 1000", "ARRAY_SIZE = 500"))
    system("git add -A")
    system("git commit -q -m 'Optimize: ARRAY_SIZE = 500 (0.5x memory)'")
    commit2 = `git rev-parse HEAD`.strip
    puts "Commit 2 (optimized): #{commit2[0..7]} - ARRAY_SIZE = 500 (0.5x - BETTER)"

    # Commit 3: ARRAY_SIZE = 2000 (double memory - WORSE)
    content = File.read("lib/allocator.rb")
    File.write("lib/allocator.rb", content.gsub("ARRAY_SIZE = 500", "ARRAY_SIZE = 2000"))
    system("git add -A")
    system("git commit -q -m 'Regression: ARRAY_SIZE = 2000 (2.0x memory)'")
    commit3 = `git rev-parse HEAD`.strip
    puts "Commit 3 (regression): #{commit3[0..7]} - ARRAY_SIZE = 2000 (2.0x - WORSE)"

    puts
    puts "Expected sorting (best to worst):"
    puts "  1. Commit 2 (0.5x - uses half the memory)"
    puts "  2. Commit 1 (1.0x - baseline)"
    puts "  3. Commit 3 (2.0x - uses double the memory)"
    puts

    # Run memory benchmarks with commit range and control commit
    puts "Running memory benchmarks..."
    puts
    system("bundle", "exec", "awfy", "memory", "start",
           "--commit_range=#{commit1}..#{commit3}",
           "--runner=commit_range",
           "--control-commit=#{commit1}",
           "--test_time=0.5",
           "--test_warm_up=0.25")

    if $?.success?
      puts
      puts "✓ Test completed successfully!"
      puts "  Check the table above - commit 2 (0.5x) should appear BEFORE commit 3 (2.0x)"
    else
      puts
      puts "✗ Test failed"
      exit 1
    end
  end
ensure
  FileUtils.remove_entry(test_repo) if test_repo && Dir.exist?(test_repo)
end
