# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class GitClientOptionalTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_outside_a_repository_nothing_raises
    client = Awfy::GitClient.new(path: @dir)
    assert_equal({branch: nil, commit_hash: nil, commit_message: nil}, client.info)
  end

  def test_info_inside_a_repository
    system("git", "init", "-q", "-b", "trunk", @dir, exception: true)
    system("git", "-C", @dir, "-c", "user.name=t", "-c", "user.email=t@example.com",
      "commit", "-q", "--allow-empty", "-m", "first", exception: true)
    info = Awfy::GitClient.new(path: @dir).info
    assert_equal "trunk", info[:branch]
    assert_equal "first", info[:commit_message]
    assert_match(/\A\h{40}\z/, info[:commit_hash])
  end

  def test_session_default_git_client_does_not_open_the_repository
    Dir.chdir(@dir) do
      config = Awfy::Config.new(storage_backend: "memory")
      session = Awfy::Session.new(shell: Awfy::Shell.new(config:), config:,
        results_store: Awfy::Stores.memory("m", Awfy::RetentionPolicies.keep_all))
      assert_nil session.git_client.info[:branch]
    end
  end
end
