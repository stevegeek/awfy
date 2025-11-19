#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for the commit range feature
# This script creates a temporary git repository with benchmarks and tests the commit range runner

require "bundler/setup"
require "tmpdir"
require "fileutils"
require "git"

class CommitRangeTest
  attr_reader :test_repo_path

  def initialize
    @test_repo_path = nil
  end

  def run
    puts "=== Commit Range Feature Test ==="
    puts

    test_same_repo_scenario
    puts
    puts "=" * 70
    puts
    test_separate_repo_scenario
  end

  def test_same_repo_scenario
    puts "## Scenario 1: Benchmarks and code in same repository"
    puts

    setup_test_repository
    create_benchmark_structure
    create_commits
    test_commit_range
  ensure
    cleanup
  end

  def test_separate_repo_scenario
    puts "## Scenario 2: Benchmarks and code in separate repositories"
    puts

    setup_separate_repositories
    create_benchmark_structure_in_benchmark_repo
    create_commits_in_code_repo
    test_commit_range_with_separate_repos
  ensure
    cleanup_separate_repos
  end

  private

  def setup_test_repository
    puts "1. Setting up temporary git repository..."
    @test_repo_path = Dir.mktmpdir("awfy_commit_range_test")
    puts "   Repository path: #{@test_repo_path}"

    # Initialize git repo
    Dir.chdir(@test_repo_path) do
      system("git init -q")
      system("git config user.name 'Test User'")
      system("git config user.email 'test@example.com'")
    end

    puts "   ✓ Git repository initialized"
    puts
  end

  def create_benchmark_structure
    puts "2. Creating benchmark structure..."

    # Create directory structure
    benchmarks_dir = File.join(@test_repo_path, "benchmarks")
    lib_dir = File.join(@test_repo_path, "lib")
    FileUtils.mkdir_p(File.join(benchmarks_dir, "tests"))
    FileUtils.mkdir_p(lib_dir)

    # Create a library file with a delay that will change across commits
    lib_file = File.join(lib_dir, "slow_operations.rb")
    File.write(lib_file, <<~RUBY)
      # Library with operations that have different performance characteristics
      module SlowOperations
        DELAY = 0.01  # Initial delay: 10ms

        def self.process_with_delay(value)
          sleep(DELAY)
          value * 2
        end
      end
    RUBY

    # Create setup file that loads the library
    setup_file = File.join(benchmarks_dir, "setup.rb")
    File.write(setup_file, <<~RUBY)
      # Benchmark setup file
      # Load the library from the repository
      $LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
      require "slow_operations"
    RUBY

    # Create benchmark test file that uses the library
    test_file = File.join(benchmarks_dir, "tests", "slow_operations.rb")
    File.write(test_file, <<~RUBY)
      # frozen_string_literal: true

      Awfy.group "Slow Operations" do
        report "Process with delay" do
          control "baseline" do
            SlowOperations.process_with_delay(5)
          end

          test "variant" do
            SlowOperations.process_with_delay(10)
          end
        end
      end
    RUBY

    puts "   ✓ Benchmark structure created"
    puts "   - lib/slow_operations.rb (DELAY = 0.01s)"
    puts "   - benchmarks/setup.rb"
    puts "   - benchmarks/tests/slow_operations.rb"
    puts
  end

  def create_commits
    puts "3. Creating test commits..."

    Dir.chdir(@test_repo_path) do
      # Initial commit with DELAY = 0.01 (10ms)
      system("git add -A")
      system("git commit -q -m 'Initial commit: DELAY = 0.01s (~100 IPS)'")
      @commit1 = `git rev-parse HEAD`.strip
      @expected_ips1 = "~100 IPS"
      puts "   ✓ Commit 1: #{@commit1[0..7]} - DELAY = 0.01s (#{@expected_ips1})"

      # Second commit - reduce delay to 0.005 (5ms) -> should be 2x faster
      lib_file = File.join("lib", "slow_operations.rb")
      content = File.read(lib_file)
      modified_content = content.gsub("DELAY = 0.01", "DELAY = 0.005")
      File.write(lib_file, modified_content)

      system("git add -A")
      system("git commit -q -m 'Optimize: DELAY = 0.005s (~200 IPS - 2x faster)'")
      @commit2 = `git rev-parse HEAD`.strip
      @expected_ips2 = "~200 IPS"
      puts "   ✓ Commit 2: #{@commit2[0..7]} - DELAY = 0.005s (#{@expected_ips2})"

      # Third commit - increase delay to 0.02 (20ms) -> should be 0.5x slower than commit 1
      content = File.read(lib_file)
      modified_content = content.gsub("DELAY = 0.005", "DELAY = 0.02")
      File.write(lib_file, modified_content)

      system("git add -A")
      system("git commit -q -m 'Regression: DELAY = 0.02s (~50 IPS - 2x slower than commit 1)'")
      @commit3 = `git rev-parse HEAD`.strip
      @expected_ips3 = "~50 IPS"
      puts "   ✓ Commit 3: #{@commit3[0..7]} - DELAY = 0.02s (#{@expected_ips3})"
    end

    puts
    puts "   Expected performance progression:"
    puts "   Commit 1: #{@expected_ips1}"
    puts "   Commit 2: #{@expected_ips2} (2x faster - optimization)"
    puts "   Commit 3: #{@expected_ips3} (4x slower than commit 2 - regression)"
    puts
  end

  def test_commit_range
    puts "4. Testing commit range feature..."
    puts

    # Test with commit range
    puts "   Testing range: #{@commit1[0..7]}..#{@commit3[0..7]}"
    puts "   Running: awfy ips start --commit_range=#{@commit1}..#{@commit3} --runner=commit_range"
    puts

    output = nil
    Dir.chdir(@test_repo_path) do
      # Run the awfy command with commit range
      # We'll use the awfy CLI directly
      awfy_command = [
        "bundle", "exec", "awfy",
        "ips", "start",
        "--commit_range=#{@commit1}..#{@commit3}",
        "--runner=commit_range",
        "--test_time=1",
        "--test_warm_up=0.5",
        "--verbose=2"
      ]

      puts "   Command: #{awfy_command.join(" ")}"
      puts
      puts "   " + "=" * 70
      puts

      # Execute the command and capture output
      require "open3"
      output, stderr, status = Open3.capture3(*awfy_command)

      # Print the output
      puts output
      puts stderr unless stderr.empty?

      puts
      puts "   " + "=" * 70
      puts

      if status.success?
        puts "   ✓ Commit range test completed successfully"

        # Verify the performance changes
        verify_performance_progression(output)
      else
        puts "   ✗ Commit range test FAILED (exit code: #{status.exitstatus})"
      end
    end

    puts
  end

  def verify_performance_progression(output)
    puts
    puts "5. Verifying performance matches code changes..."
    puts

    # Extract IPS values for each commit from the output
    # Look for lines like: │ 2025-... │ HEAD │ abc1234 │ yjit │ ✓ │ ... │ 123.45 │ ...
    commit_results = {}

    output.lines.each do |line|
      # Match table rows with commit hash, control marker, and IPS value
      # Format: │ timestamp │ branch │ commit │ runtime │ ✓ │ name │ ips_display │ ips_value │ ...
      if line =~ /│\s+[\d-]+…\s+│\s+\w+\s+│\s+(\w+)…\s+│\s+\w+\s+│\s+✓\s+│\s+\S+…\s+│\s+[\d,.]+…\s+│\s+([\d,]+)\s+│/
        commit_short = $1
        ips_value = $2.gsub(',', '').to_f

        # Map to full commits (check if full commit starts with the short hash from table)
        if @commit1.start_with?(commit_short)
          commit_results[:commit1] ||= []
          commit_results[:commit1] << ips_value
        elsif @commit2.start_with?(commit_short)
          commit_results[:commit2] ||= []
          commit_results[:commit2] << ips_value
        elsif @commit3.start_with?(commit_short)
          commit_results[:commit3] ||= []
          commit_results[:commit3] << ips_value
        end
      end
    end

    # Calculate average IPS for each commit (might have multiple runtimes)
    avg_ips1 = commit_results[:commit1]&.sum&./(commit_results[:commit1]&.size || 1) || 0
    avg_ips2 = commit_results[:commit2]&.sum&./(commit_results[:commit2]&.size || 1) || 0
    avg_ips3 = commit_results[:commit3]&.sum&./(commit_results[:commit3]&.size || 1) || 0

    puts "   Commit 1 (#{@commit1[0..7]}): #{avg_ips1.round(1)} IPS (expected ~100)"
    puts "   Commit 2 (#{@commit2[0..7]}): #{avg_ips2.round(1)} IPS (expected ~200, 2x faster)"
    puts "   Commit 3 (#{@commit3[0..7]}): #{avg_ips3.round(1)} IPS (expected ~50, 2x slower than commit 1)"
    puts

    # Verify the relationships (with some tolerance for variance)
    commit2_vs_commit1 = avg_ips2 / avg_ips1 if avg_ips1 > 0
    commit3_vs_commit1 = avg_ips3 / avg_ips1 if avg_ips1 > 0

    verification_passed = true

    if commit2_vs_commit1 && commit2_vs_commit1 > 1.5  # Should be ~2x
      puts "   ✓ Commit 2 is faster than Commit 1 (#{commit2_vs_commit1.round(2)}x)"
    else
      puts "   ✗ Commit 2 should be ~2x faster than Commit 1 (got #{commit2_vs_commit1&.round(2)}x)"
      verification_passed = false
    end

    if commit3_vs_commit1 && commit3_vs_commit1 < 0.7  # Should be ~0.5x
      puts "   ✓ Commit 3 is slower than Commit 1 (#{commit3_vs_commit1.round(2)}x)"
    else
      puts "   ✗ Commit 3 should be ~0.5x slower than Commit 1 (got #{commit3_vs_commit1&.round(2)}x)"
      verification_passed = false
    end

    puts
    if verification_passed
      puts "   ✓✓ VERIFICATION PASSED: Code changes are reflected in benchmark results!"
      puts "   The commit range runner is correctly checking out and running against different code versions."
    else
      puts "   ✗✗ VERIFICATION FAILED: Performance doesn't match expected code changes"
      puts "   This suggests the runner may not be checking out the correct code for each commit."
    end
    puts
  end

  def cleanup
    if @test_repo_path && Dir.exist?(@test_repo_path)
      puts "6. Cleaning up..."
      FileUtils.remove_entry(@test_repo_path)
      puts "   ✓ Temporary repository removed"
      puts
    end
  end

  # Separate repo scenario methods

  def setup_separate_repositories
    puts "1. Setting up separate repositories..."

    # Create benchmark repo (no git needed)
    @benchmark_repo_path = Dir.mktmpdir("awfy_benchmarks")
    puts "   Benchmark path: #{@benchmark_repo_path}"

    # Create code repo with git
    @code_repo_path = Dir.mktmpdir("awfy_code_repo")
    puts "   Code repository path: #{@code_repo_path}"

    # Initialize git repo in code directory
    Dir.chdir(@code_repo_path) do
      system("git init -q")
      system("git config user.name 'Test User'")
      system("git config user.email 'test@example.com'")
    end

    puts "   ✓ Separate repositories initialized"
    puts
  end

  def create_benchmark_structure_in_benchmark_repo
    puts "2. Creating benchmark structure in benchmark repo..."

    # Create directory structure
    benchmarks_dir = File.join(@benchmark_repo_path, "benchmarks")
    FileUtils.mkdir_p(File.join(benchmarks_dir, "tests"))

    # Create setup file that requires code from the code repo
    setup_file = File.join(benchmarks_dir, "setup.rb")
    File.write(setup_file, <<~RUBY)
      # Benchmark setup file
      # Load the code from the separate repository
      $LOAD_PATH.unshift("#{@code_repo_path}/lib")
    RUBY

    # Create a simple benchmark test file
    test_file = File.join(benchmarks_dir, "tests", "array_operations.rb")
    File.write(test_file, <<~RUBY)
      # frozen_string_literal: true

      Awfy.group "Array Operations" do
        report "Array#map" do
          control "map with times" do
            [1, 2, 3, 4, 5].map { |x| x * 2 }
          end

          test "map with plus" do
            [1, 2, 3, 4, 5].map { |x| x + x }
          end
        end

        report "Array#select" do
          control "select even" do
            [1, 2, 3, 4, 5].select { |x| x.even? }
          end

          test "select odd" do
            [1, 2, 3, 4, 5].select { |x| x.odd? }
          end
        end
      end
    RUBY

    puts "   ✓ Benchmark structure created"
    puts "   - #{@benchmark_repo_path}/benchmarks/setup.rb"
    puts "   - #{@benchmark_repo_path}/benchmarks/tests/array_operations.rb"
    puts
  end

  def create_commits_in_code_repo
    puts "3. Creating commits in code repository..."

    Dir.chdir(@code_repo_path) do
      # Create lib directory
      FileUtils.mkdir_p("lib")

      # Initial commit - create a simple library file
      File.write("lib/my_code.rb", <<~RUBY)
        # My code library
        module MyCode
          VERSION = "1.0.0"
        end
      RUBY

      system("git add -A")
      system("git commit -q -m 'Initial commit'")
      @commit1 = `git rev-parse HEAD`.strip
      puts "   ✓ Commit 1: #{@commit1[0..7]} - Initial commit"

      # Second commit - update version
      File.write("lib/my_code.rb", <<~RUBY)
        # My code library
        module MyCode
          VERSION = "1.1.0"
        end
      RUBY

      system("git add -A")
      system("git commit -q -m 'Bump version to 1.1.0'")
      @commit2 = `git rev-parse HEAD`.strip
      puts "   ✓ Commit 2: #{@commit2[0..7]} - Version bump"

      # Third commit - add new functionality
      File.write("lib/my_code.rb", <<~RUBY)
        # My code library
        module MyCode
          VERSION = "1.2.0"

          def self.greet(name)
            "Hello, \#{name}!"
          end
        end
      RUBY

      system("git add -A")
      system("git commit -q -m 'Add greet method'")
      @commit3 = `git rev-parse HEAD`.strip
      puts "   ✓ Commit 3: #{@commit3[0..7]} - Added greet method"
    end

    puts
  end

  def test_commit_range_with_separate_repos
    puts "4. Testing commit range with separate repositories..."
    puts

    # Test with commit range and target repo
    puts "   Testing range: #{@commit1[0..7]}..#{@commit3[0..7]}"
    puts "   Benchmark repo: #{@benchmark_repo_path}"
    puts "   Code repo: #{@code_repo_path}"
    puts

    Dir.chdir(@benchmark_repo_path) do
      # Run the awfy command with commit range and target repo path
      awfy_command = [
        "bundle", "exec", "awfy",
        "ips", "start",
        "--commit_range=#{@commit1}..#{@commit3}",
        "--runner=commit_range",
        "--target-repo-path=#{@code_repo_path}",
        "--test_time=1",
        "--test_warm_up=0.5",
        "--verbose=2"
      ]

      puts "   Command: #{awfy_command.join(" ")}"
      puts
      puts "   " + "=" * 70
      puts

      # Execute the command
      success = system(*awfy_command)

      puts
      puts "   " + "=" * 70
      puts

      if success
        puts "   ✓ Separate repo test PASSED"
      else
        puts "   ✗ Separate repo test FAILED (exit code: #{$?.exitstatus})"
      end
    end

    puts
  end

  def cleanup_separate_repos
    if @benchmark_repo_path && Dir.exist?(@benchmark_repo_path)
      puts "5. Cleaning up..."
      FileUtils.remove_entry(@benchmark_repo_path)
      puts "   ✓ Benchmark repository removed"
    end

    if @code_repo_path && Dir.exist?(@code_repo_path)
      FileUtils.remove_entry(@code_repo_path)
      puts "   ✓ Code repository removed"
      puts
    end
  end
end

# Run the test
if __FILE__ == $0
  test = CommitRangeTest.new
  test.run
end
