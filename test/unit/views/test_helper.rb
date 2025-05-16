# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"
require "ostruct"

# Custom Shell class for testing views
class TestShell < Awfy::Shell
  attr_reader :messages, :errors

  def after_initialize
    super
    @messages = []
    @errors = []
  end

  def say(message = "", color = nil)
    @messages << {message: message, color: color}
  end

  def say_error(message)
    @errors << message
  end
end

# Test case base class with common setup for view tests
class ViewTestCase < Minitest::Test
  def setup
    # Create proper Awfy objects instead of mocks
    @config = Awfy::Config.new(
      verbose: Awfy::VerbosityLevel::NONE.value, # Corrected: Use VerbosityLevel enum value
      summary: true,
      summary_order: "desc"
    )

    @shell = TestShell.new(config: @config)

    # Create a git client to satisfy the type requirements
    @git_client = Awfy::GitClient.new(path: Dir.pwd)

    # Create a memory store with a keep_all retention policy
    retention_policy = Awfy::RetentionPolicies.keep_all
    @results_store = Awfy::Stores::Memory.new(
      storage_name: "test_memory_store",
      retention_policy: retention_policy
    )

    # Create a proper Awfy::Session
    @session = Awfy::Session.new(
      shell: @shell,
      config: @config,
      git_client: @git_client,
      results_store: @results_store
    )
  end

  def capture_output
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

  # Generate results by commit for view tests
  def generate_results_by_commit(num_commits = 3, with_mri = true, with_yjit = true, type = :memory)
    results = {}

    (1..num_commits).each do |i|
      commit = "000commit#{i}"
      results[commit] = {}

      if with_mri
        if type == :memory
          results[commit][:mri] = [
            create_test_result(
              type: :memory,
              runtime: Awfy::Runtimes::MRI,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test1",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test1",
              allocated_memsize: 100000 * i,
              allocated_objects: 1000 * i
            ),
            create_test_result(
              type: :memory,
              runtime: Awfy::Runtimes::MRI,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test2",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test2",
              allocated_memsize: 200000 * i,
              allocated_objects: 2000 * i
            )
          ]
        elsif type == :ips
          results[commit][:mri] = [
            create_test_result(
              type: :ips,
              runtime: Awfy::Runtimes::MRI,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test1",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test1",
              ips: 1000.0 * i
            ),
            create_test_result(
              type: :ips,
              runtime: Awfy::Runtimes::MRI,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test2",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test2",
              ips: 2000.0 * i
            )
          ]
        end
      end

      if with_yjit
        if type == :memory
          results[commit][:yjit] = [
            create_test_result(
              type: :memory,
              runtime: Awfy::Runtimes::YJIT,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test1",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test1",
              allocated_memsize: 100000 * i,
              allocated_objects: 1000 * i
            ),
            create_test_result(
              type: :memory,
              runtime: Awfy::Runtimes::YJIT,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test2",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test2",
              allocated_memsize: 200000 * i,
              allocated_objects: 2000 * i
            )
          ]
        elsif type == :ips
          results[commit][:yjit] = [
            create_test_result(
              type: :ips,
              runtime: Awfy::Runtimes::YJIT,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test1",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test1",
              ips: 1500.0 * i
            ),
            create_test_result(
              type: :ips,
              runtime: Awfy::Runtimes::YJIT,
              group_name: "test_group",
              report_name: "test_report",
              test_name: "test2",
              commit_hash: commit,
              commit_message: "Commit message #{i}",
              label: "test2",
              ips: 3000.0 * i
            )
          ]
        end
      end
    end

    sorted_commits = results.keys.sort

    [sorted_commits, results]
  end

  # Helper method to create a Result object
  def create_test_result(type:, runtime:, group_name:, report_name:, test_name:, result_data: nil, commit_hash:, commit_message:, label:, allocated_memsize: nil, allocated_objects: nil, ips: nil)
    result_data ||= {
      label:
    }

    # Add appropriate data based on test type
    if type == :memory
      result_data[:allocated_memsize] = allocated_memsize if allocated_memsize
      result_data[:allocated_objects] = allocated_objects if allocated_objects
    elsif type == :ips
      result_data[:ips] = ips if ips
    end

    Awfy::Result.new(
      type: type,
      runtime: runtime,
      group_name: group_name,
      report_name: report_name,
      test_name: test_name,
      branch: "main",
      commit_hash: commit_hash,
      commit_message: commit_message,
      timestamp: Time.now,
      result_data: result_data
    )
  end
end
