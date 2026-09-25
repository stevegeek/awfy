# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

# Runs real child awfy processes against a small suite written to a temporary directory.
class TestSpawnRunner < Minitest::Test
  include RunnerTestHelpers

  def setup
    @dir = File.realpath(Dir.mktmpdir("awfy_spawn"))
    @pids_dir = File.join(@dir, "pids")
    FileUtils.mkdir_p([@pids_dir, File.join(@dir, "tests")])
    File.write(File.join(@dir, "setup.rb"), "")
    File.write(File.join(@dir, "tests", "suite.rb"), <<~RUBY)
      ["Spawned Group", "Other Group"].each do |name|
        Awfy.group name do
          report "pid" do
            test "records its process" do
              File.write(File.join(#{@pids_dir.inspect}, name.tr(" ", "_") + "-" + Process.pid.to_s), "")
            end
          end
        end
      end

      Awfy.group "Failing Group" do
        report "boom" do
          test "raises" do
            raise "failure inside the child"
          end
        end
      end
    RUBY

    @config = Awfy::Config.new(
      runtime: "mri",
      test_iterations: 1,
      setup_file_path: File.join(@dir, "setup"),
      tests_path: File.join(@dir, "tests"),
      storage_backend: Awfy::StoreAliases::Memory,
      storage_name: File.join(@dir, "store"),
      color: Awfy::ColorMode::OFF,
      summary: false
    )
    @session = create_test_session(@config)
    @suite = Awfy::Suite.new(["Spawned Group", "Other Group", "Failing Group"].map { |name| group_named(name) })
    @runner = Awfy::Runners::Sequential::SpawnRunner.new(suite: @suite, session: @session)
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
  end

  def group_named(name)
    test = Awfy::Suites::Test.new(name: "records its process", block: proc {})
    Awfy::Suites::Group.new(name: name, reports: [Awfy::Suites::Report.new(name: "pid", tests: [test])])
  end

  def run_group_job(group)
    Awfy::Jobs::RunGroup.new(
      session: @session,
      group: group,
      benchmarker: Awfy::Benchmarker.new(session: @session),
      results_manager: Awfy::ResultsManager.new(session: @session)
    )
  end

  def recorded_pids(group_name)
    Dir.children(@pids_dir).grep(/\A#{group_name.tr(" ", "_")}-/).map { |file| file.split("-").last.to_i }
  end

  def test_runs_the_group_in_another_process
    capture_io { @runner.run("Spawned Group") { |group| run_group_job(group) } }

    pids = recorded_pids("Spawned Group")
    assert_equal 1, pids.size
    refute_equal Process.pid, pids.first
    assert_empty recorded_pids("Other Group")
  end

  def test_raises_with_the_child_output_when_the_child_fails
    error = nil
    capture_io do
      error = assert_raises(RuntimeError) { @runner.run("Failing Group") { |group| run_group_job(group) } }
    end

    assert_match(/failure inside the child/, error.message)
  end

  def test_raises_without_a_block
    assert_raises(ArgumentError) { @runner.run_group(@suite.find_group("Spawned Group")) }
  end

  def test_rejects_jobs_that_cannot_run_in_a_child_process
    assert_raises(ArgumentError) { @runner.run("Spawned Group") { Object.new } }
    assert_empty recorded_pids("Spawned Group")
  end
end
