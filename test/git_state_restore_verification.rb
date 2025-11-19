#!/usr/bin/env ruby
# frozen_string_literal: true

# Verification test that git state is properly restored after commit range runs

require "bundler/setup"
require "tmpdir"
require "fileutils"

puts "Verifying git state restoration after commit range..."
puts

test_repo = Dir.mktmpdir("awfy_git_restore_test")

begin
  Dir.chdir(test_repo) do
    # Initialize git repo
    system("git init -q")
    system("git config user.name 'Test User'")
    system("git config user.email 'test@example.com'")

    # Create benchmark structure
    FileUtils.mkdir_p("benchmarks/tests")
    FileUtils.mkdir_p("lib")

    # Create a simple library
    File.write("lib/simple.rb", <<~RUBY)
      module Simple
        def self.run
          "hello"
        end
      end
    RUBY

    # Setup file
    File.write("benchmarks/setup.rb", <<~RUBY)
      require_relative "../../lib/simple"
    RUBY

    # Simple benchmark
    File.write("benchmarks/tests/simple.rb", <<~RUBY)
      Awfy.group "Test" do
        report "Simple" do
          control "baseline" do
            Simple.run
          end

          test "variant" do
            Simple.run
          end
        end
      end
    RUBY

    # Create 3 commits
    system("git add -A")
    system("git commit -q -m 'Commit 1'")
    commit1 = `git rev-parse HEAD`.strip

    File.write("lib/simple.rb", <<~RUBY)
      module Simple
        def self.run
          "hello world"
        end
      end
    RUBY
    system("git add -A")
    system("git commit -q -m 'Commit 2'")
    commit2 = `git rev-parse HEAD`.strip

    File.write("lib/simple.rb", <<~RUBY)
      module Simple
        def self.run
          "hello world!"
        end
      end
    RUBY
    system("git add -A")
    system("git commit -q -m 'Commit 3'")
    commit3 = `git rev-parse HEAD`.strip

    # Test 1: Restore when on a branch
    system("git checkout -q -b test-branch")
    original_branch = `git branch --show-current`.strip
    original_head = `git rev-parse HEAD`.strip

    puts "Test 1: Branch state restoration"
    puts "  Before: branch=#{original_branch}, HEAD=#{original_head[0..7]}"

    system("bundle", "exec", "awfy", "ips", "start",
           "--commit_range=#{commit1}..#{commit3}",
           "--runner=commit_range",
           "--test_time=0.5",
           "--test_warm_up=0.25",
           "--quiet")

    after_branch = `git branch --show-current`.strip
    after_head = `git rev-parse HEAD`.strip
    puts "  After:  branch=#{after_branch}, HEAD=#{after_head[0..7]}"

    if after_branch == original_branch && after_head == original_head
      puts "  ✓ Branch state restored correctly"
    else
      puts "  ✗ FAILED: Branch state not restored!"
      exit 1
    end

    puts
    puts "Test 2: Detached HEAD state restoration"

    # Checkout to detached HEAD
    system("git checkout -q #{commit2}")
    original_head_detached = `git rev-parse HEAD`.strip

    puts "  Before: HEAD=#{original_head_detached[0..7]} (detached)"

    system("bundle", "exec", "awfy", "ips", "start",
           "--commit_range=#{commit1}..#{commit3}",
           "--runner=commit_range",
           "--test_time=0.5",
           "--test_warm_up=0.25",
           "--quiet")

    after_head_detached = `git rev-parse HEAD`.strip
    after_branch_detached = `git branch --show-current`.strip

    puts "  After:  HEAD=#{after_head_detached[0..7]}#{after_branch_detached.empty? ? ' (detached)' : ''}"

    if after_head_detached == original_head_detached && after_branch_detached.empty?
      puts "  ✓ Detached HEAD state restored correctly"
    else
      puts "  ✗ FAILED: Detached HEAD state not restored!"
      exit 1
    end

    puts
    puts "Test 3: Stash handling with uncommitted changes"

    # Go back to branch and make uncommitted changes
    system("git checkout -q test-branch")
    File.write("lib/simple.rb", <<~RUBY)
      module Simple
        def self.run
          "uncommitted change"
        end
      end
    RUBY

    original_content = File.read("lib/simple.rb")
    puts "  Before: uncommitted changes present"

    system("bundle", "exec", "awfy", "ips", "start",
           "--commit_range=#{commit1}..#{commit3}",
           "--runner=commit_range",
           "--test_time=0.5",
           "--test_warm_up=0.25",
           "--quiet")

    after_content = File.read("lib/simple.rb")
    after_branch_final = `git branch --show-current`.strip

    puts "  After:  branch=#{after_branch_final}"

    if after_content == original_content && after_branch_final == "test-branch"
      puts "  ✓ Uncommitted changes restored correctly"
    else
      puts "  ✗ FAILED: Changes not restored!"
      exit 1
    end
  end
ensure
  FileUtils.remove_entry(test_repo) if test_repo && Dir.exist?(test_repo)
end

puts
puts "✓✓✓ All git state restoration tests passed!"
