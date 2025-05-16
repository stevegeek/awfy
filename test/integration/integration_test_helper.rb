# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"
require "json"
require "securerandom"
require "test_helper"

module IntegrationTestHelper
  def setup_test_environment
    # Create a unique ID for this test instance
    @test_instance_id = SecureRandom.hex(8)

    # Create a test directory with unique name inside /tmp
    @test_dir = File.join(Dir.tmpdir, "awfy_test_#{@test_instance_id}")
    FileUtils.mkdir_p(@test_dir)
    @original_dir = Dir.pwd

    # Create necessary directory structure for benchmarks
    create_benchmark_dirs

    # Copy fixture files to test directory
    copy_fixtures_to_test_dir

    # Setup a git repository with known state
    setup_git_repository

    # Generate a unique database name for this test run
    @test_db_name = "test_db_#{@test_instance_id}"
    @test_db_path = File.join(@test_dir, @test_db_name)

    # Change to test directory
    Dir.chdir(@test_dir)
  end

  def teardown_test_environment
    Dir.chdir(@original_dir)

    # Explicitly delete the SQLite database file if it exists
    db_file = "#{@test_db_path}.db"
    FileUtils.rm(db_file) if File.exist?(db_file)

    # Remove only this test's directory
    FileUtils.remove_entry(@test_dir) if Dir.exist?(@test_dir)
  end

  def create_benchmark_dirs
    # Create directory structure needed by the application
    FileUtils.mkdir_p(File.join(@test_dir, "benchmarks/tmp"))
    FileUtils.mkdir_p(File.join(@test_dir, "benchmarks/saved"))
    FileUtils.mkdir_p(File.join(@test_dir, "benchmarks/tests"))
  end

  def copy_fixtures_to_test_dir
    fixtures_dir = File.join(File.dirname(__FILE__), "..", "fixtures")
    return unless File.directory?(fixtures_dir)

    FileUtils.cp_r(File.join(fixtures_dir, "."), @test_dir)
  end

  def setup_git_repository
    # Initialize a new git repository
    Dir.chdir(@test_dir) do
      # Redirect output to /dev/null to suppress git messages
      system("git init -b main > /dev/null 2>&1")

      # Configure git user
      system('git config --local user.name "Test User" > /dev/null 2>&1')
      system('git config --local user.email "test@example.com" > /dev/null 2>&1')

      # Add all files and create initial commit
      system("git add . > /dev/null 2>&1")
      result = system('git commit -m "Initial commit for integration test" > /dev/null 2>&1')

      puts "Failed to create git repository. Tests requiring git may fail." unless result
    end
  end

  def capture_command_output
    original_stdout = $stdout
    output_capture = StringIO.new
    $stdout = output_capture

    begin
      yield
      output_capture.string
    ensure
      $stdout = original_stdout
    end
  end

  # Create multiple commits for testing commit range features
  def create_multiple_commits(count = 3)
    Dir.chdir(@test_dir) do
      # Create commits with slight variations in the benchmark file
      count.times do |i|
        # Modify benchmark file to create a change
        benchmark_file = File.join("benchmarks/tests/benchmark.rb")
        content = File.read(benchmark_file)
        iterations = ENV.fetch("AWFY_TEST_ITERATIONS", "10").to_i
        content.gsub!(/\d+\.times/, "#{iterations}.times")
        File.write(benchmark_file, content)

        # Create commit with suppressed output
        system("git add #{benchmark_file} > /dev/null 2>&1")
        system("git commit -m \"Commit #{i + 1}: Update benchmark\" > /dev/null 2>&1")
      end
    end
  end

  # Get a list of commits in the test repository
  def get_commit_list(count = nil)
    Dir.chdir(@test_dir) do
      cmd = "git log --format=%H"
      cmd += " -n #{count}" if count
      cmd += " 2>/dev/null" # Suppress stderr output
      `#{cmd}`.strip.split("\n")
    end
  end

  def run_command(command, *args, options: {})
    # Thor options need to be passed properly
    thor_options = options

    # Add fast benchmark settings from environment if not already specified
    thor_options[:test_time] ||= ENV.fetch("AWFY_TEST_TIME", "0.01").to_f
    thor_options[:test_warm_up] ||= ENV.fetch("AWFY_TEST_WARM_UP", "0.01").to_f
    thor_options[:test_iterations] ||= ENV.fetch("AWFY_TEST_ITERATIONS", "1").to_i

    # Use SQLite store with a unique database name for this test run
    thor_options[:storage_backend] = "sqlite"
    thor_options[:storage_name] = @test_db_path

    # Set color mode for tests
    thor_options[:color] = "off"

    # Start the CLI with command and all processed args
    capture_command_output do
      Awfy::CLI.new.invoke(command, args, thor_options)
    end
  end

  # Check if a result file exists
  def result_exists?(type)
    pattern = File.join(@test_dir, "benchmarks/tmp/*-#{type}-*.json")
    !Dir.glob(pattern).empty?
  end

  # Verify benchmark files are created
  def assert_benchmark_results_saved(type)
    pattern = File.join(@test_dir, "benchmarks/saved/*-#{type}-*.json")
    files = Dir.glob(pattern)
    assert_not files.empty?, "No benchmark result files found for type: #{type}"
    files
  end
end
