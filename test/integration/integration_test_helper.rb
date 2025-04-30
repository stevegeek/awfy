# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"
require "json"
require "awfy"

module IntegrationTestHelper
  def setup_test_environment
    @test_dir = Dir.mktmpdir
    @original_dir = Dir.pwd

    # Create necessary directory structure for benchmarks
    create_benchmark_dirs

    # Copy fixture files to test directory
    copy_fixtures_to_test_dir

    # Setup a git repository with known state
    setup_git_repository

    # Change to test directory
    Dir.chdir(@test_dir)
  end

  def teardown_test_environment
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@test_dir)
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
      system("git init -b main")

      # Configure git user
      system('git config --local user.name "Test User"')
      system('git config --local user.email "test@example.com"')

      # Add all files and create initial commit
      system("git add .")
      result = system('git commit -m "Initial commit for integration test"')

      puts "Failed to create git repository. Tests requiring git may fail." unless result
    end
  end

  def capture_command_output
    original_stdout = $stdout
    output_capture = StringIO.new
    $stdout = output_capture
    yield
    output_capture.string.tap do |output|
      puts output if ENV["VERBOSE"]
    end
  ensure
    $stdout = original_stdout
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

        # Create commit
        system("git add #{benchmark_file}")
        system("git commit -m \"Commit #{i + 1}: Update benchmark\"")
      end
    end
  end

  # Get a list of commits in the test repository
  def get_commit_list(count = nil)
    Dir.chdir(@test_dir) do
      cmd = "git log --format=%H"
      cmd += " -n #{count}" if count
      `#{cmd}`.strip.split("\n")
    end
  end

  def run_command(command, *args, options: {})
    # Thor options need to be passed properly
    thor_options = options

    # Add fast benchmark settings from environment if not already specified
    thor_options[:ips_time] ||= ENV.fetch("AWFY_TEST_TIME", "0.01").to_f
    thor_options[:ips_warmup] ||= ENV.fetch("AWFY_TEST_WARM_UP", "0.01").to_f
    thor_options[:test_iterations] ||= ENV.fetch("AWFY_TEST_ITERATIONS", "10").to_i
    thor_options[:verbose] = ENV["VERBOSE"] if ENV["VERBOSE"]

    # Make sure we're using our memory result store for tests
    thor_options[:storage_backend] = :memory

    # Reset the result store factory before each command
    Awfy::ResultStoreFactory.reset!

    # Start the CLI with command and all processed args
    capture_command_output do
      cli = Awfy::CLI.new([], thor_options)
      cli.public_send(command, *args)
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
