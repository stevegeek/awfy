# frozen_string_literal: true

require "test_helper"
require_relative "test_helper"

class TestChildCommand < Minitest::Test
  include RunnerTestHelpers

  def setup
    @config = Awfy::Config.new(
      runtime: "mri",
      test_time: 0.5,
      test_warm_up: 0.25,
      test_iterations: 10,
      setup_file_path: "/bench/setup",
      tests_path: "/bench/tests",
      storage_backend: Awfy::StoreAliases::SQLite,
      storage_name: "/bench/history",
      retention_policy: Awfy::RetentionPolicyAliases::Date,
      retention_days: 7,
      color: Awfy::ColorMode::OFF,
      compare_with_branch: "main",
      commit_range: "a..b",
      runner: Awfy::RunnerTypes::SPAWN
    )
    @session = create_test_session(@config)
    @group = create_mock_suite.find_group("test_group")
  end

  def job(klass)
    klass.new(
      session: @session,
      group: @group,
      benchmarker: Awfy::Benchmarker.new(session: @session),
      results_manager: Awfy::ResultsManager.new(session: create_test_session(create_test_options(nil)))
    )
  end

  # A command whose argv is replaced, to exercise #run! without booting awfy.
  def with_argv(*argv)
    Class.new(Awfy::Runners::ChildCommand) { define_method(:argv) { argv } }
      .new(subcommand: %w[ips start], group_name: "g", config: @config)
  end

  def test_picks_the_subcommand_that_runs_the_same_job
    assert_equal %w[ips start], Awfy::Runners::ChildCommand.for_job(job(Awfy::Jobs::IPS), group_name: "g", config: @config).subcommand
    assert_equal %w[memory start], Awfy::Runners::ChildCommand.for_job(job(Awfy::Jobs::Memory), group_name: "g", config: @config).subcommand
    assert_equal %w[suite debug], Awfy::Runners::ChildCommand.for_job(job(Awfy::Jobs::RunGroup), group_name: "g", config: @config).subcommand
  end

  def test_rejects_jobs_that_have_no_subcommand
    error = assert_raises(ArgumentError) do
      Awfy::Runners::ChildCommand.for_job(Object.new, group_name: "g", config: @config)
    end
    assert_match(/Object/, error.message)
  end

  def test_argv_keeps_the_group_name_as_one_argument
    argv = Awfy::Runners::ChildCommand.new(subcommand: %w[ips start], group_name: "My Group", config: @config).argv

    assert_equal ["bundle", "exec", "awfy", "ips", "start", "My Group"], argv.first(6)
  end

  def test_argv_forwards_the_options_that_shape_a_run
    argv = Awfy::Runners::ChildCommand.new(subcommand: %w[ips start], group_name: "g", config: @config).argv

    %w[
      --runtime=mri --test-time=0.5 --test-warm-up=0.25 --test-iterations=10
      --setup-file-path=/bench/setup --tests-path=/bench/tests
      --storage-backend=sqlite --storage-name=/bench/history
      --retention-policy=date --retention-days=7 --color=off --verbose=0 --summary
    ].each { |option| assert_includes argv, option }
  end

  def test_argv_never_forwards_the_options_that_pick_a_runner
    argv = Awfy::Runners::ChildCommand.new(subcommand: %w[ips start], group_name: "g", config: @config).argv.join(" ")

    refute_match(/--compare-with-branch|--commit-range|--runner/, argv)
  end

  def test_argv_adds_control_commit_and_can_turn_off_the_summary
    argv = Awfy::Runners::ChildCommand.new(subcommand: %w[ips start], group_name: "g", config: @config,
      control_commit: "abc123", summary: false).argv

    assert_includes argv, "--control-commit=abc123"
    assert_includes argv, "--no-summary"
    refute_includes argv, "--summary"
  end

  def test_argv_passes_quiet_for_a_muted_config
    config = Awfy::Config.new(verbose: Awfy::VerbosityLevel::MUTE)
    argv = Awfy::Runners::ChildCommand.new(subcommand: %w[ips start], group_name: "g", config: config).argv

    assert_includes argv, "--quiet"
    refute(argv.any? { |arg| arg.start_with?("--verbose") })
  end

  def test_run_returns_the_output_of_a_successful_command
    command = with_argv("ruby", "-e", "puts :out; warn :err")

    output = command.run!

    assert_includes output, "out"
    assert_includes output, "err"
  end

  def test_run_raises_with_the_exit_status_and_output_of_a_failed_command
    command = with_argv("ruby", "-e", "warn %q(boom); exit 3")

    error = assert_raises(RuntimeError) { command.run! }

    assert_match(/exit status 3/, error.message)
    assert_match(/boom/, error.message)
  end
end
