# frozen_string_literal: true

require "test_helper"
require "git_repo_helper"

# Exercises GitClient#stashed_checkout and #preserving_worktree against real repositories.
class TestGitClientCheckout < Minitest::Test
  include GitRepoHelper

  def setup
    @repo = create_git_repo
    @feature_sha = nil
    git(@repo, "checkout", "-q", "-b", "feature")
    @feature_sha = commit_file(@repo, "file.txt", "feature\n", "Feature change")
    git(@repo, "checkout", "-q", "main")
    @client = Awfy::GitClient.new(path: @repo)
  end

  def teardown
    FileUtils.remove_entry(@repo) if @repo && Dir.exist?(@repo)
  end

  def test_runs_the_block_on_the_ref_and_returns_to_the_branch
    seen = nil
    @client.stashed_checkout("feature") { seen = read_file(@repo, "file.txt") }

    assert_equal "feature\n", seen
    assert_equal "main", head_ref(@repo)
    assert_equal "main\n", read_file(@repo, "file.txt")
  end

  def test_restores_uncommitted_and_staged_changes
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    File.write(File.join(@repo, "staged.txt"), "staged\n")
    git(@repo, "add", "staged.txt")

    seen = nil
    @client.stashed_checkout("feature") { seen = read_file(@repo, "file.txt") }

    assert_equal "feature\n", seen
    assert_equal "main", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal "A  staged.txt", git(@repo, "status", "--porcelain", "--", "staged.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_leaves_the_stash_alone_when_there_is_nothing_to_stash
    File.write(File.join(@repo, "file.txt"), "older\n")
    git(@repo, "stash", "push", "-q", "-m", "someone else's work")

    @client.stashed_checkout("feature") {}

    assert_equal 1, stash_count(@repo)
    assert_match(/someone else's work/, git(@repo, "stash", "list"))
    assert_equal "main\n", read_file(@repo, "file.txt")
  end

  def test_pops_its_own_stash_even_when_another_entry_was_pushed_meanwhile
    File.write(File.join(@repo, "file.txt"), "mine\n")

    @client.stashed_checkout("feature") do
      File.write(File.join(@repo, "file.txt"), "theirs\n")
      git(@repo, "stash", "push", "-q", "-m", "pushed during the run")
    end

    assert_equal "mine\n", read_file(@repo, "file.txt")
    assert_equal 1, stash_count(@repo)
    assert_match(/pushed during the run/, git(@repo, "stash", "list"))
  end

  def test_restores_the_branch_and_changes_when_the_block_raises
    File.write(File.join(@repo, "file.txt"), "work in progress\n")

    error = assert_raises(RuntimeError) do
      @client.stashed_checkout("feature") { raise "benchmark failed" }
    end

    assert_equal "benchmark failed", error.message
    assert_equal "main", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_restores_changes_when_the_ref_cannot_be_checked_out
    File.write(File.join(@repo, "file.txt"), "work in progress\n")
    ran = false

    assert_raises(Git::FailedError) do
      @client.stashed_checkout("no-such-branch") { ran = true }
    end

    refute ran
    assert_equal "main", head_ref(@repo)
    assert_equal "work in progress\n", read_file(@repo, "file.txt")
    assert_equal 0, stash_count(@repo)
  end

  def test_returns_to_the_same_commit_when_head_is_detached
    main_sha = git(@repo, "rev-parse", "main")
    git(@repo, "checkout", "-q", "--detach", main_sha)

    @client.stashed_checkout("feature") {}

    assert_equal main_sha, head_ref(@repo)
    assert_equal "HEAD", git(@repo, "rev-parse", "--abbrev-ref", "HEAD")
  end

  def test_preserving_worktree_yields_the_original_ref
    yielded = nil
    @client.preserving_worktree { |ref| yielded = ref }
    assert_equal "main", yielded
  end

  def test_refuses_while_a_merge_is_in_progress
    commit_file(@repo, "file.txt", "conflicting\n", "Conflicting change")
    Open3.capture3("git", "-C", @repo, "merge", "feature")
    status_before = git(@repo, "status", "--porcelain")

    error = assert_raises(Awfy::Errors::UnsafeCheckoutError) do
      @client.stashed_checkout("feature") { flunk "block must not run" }
    end

    assert_match(/merge/, error.message)
    assert_equal status_before, git(@repo, "status", "--porcelain")
    assert_equal 0, stash_count(@repo)
  end

  def test_refuses_while_a_rebase_is_in_progress
    commit_file(@repo, "file.txt", "conflicting\n", "Conflicting change")
    Open3.capture3("git", "-C", @repo, "rebase", "feature")

    error = assert_raises(Awfy::Errors::UnsafeCheckoutError) do
      @client.stashed_checkout("feature") { flunk "block must not run" }
    end

    assert_match(/rebase/, error.message)
  end

  def test_refuses_when_head_has_no_commit
    empty = File.realpath(Dir.mktmpdir("awfy_empty_repo"))
    git(empty, "init", "-q", "-b", "main")

    error = assert_raises(Awfy::Errors::UnsafeCheckoutError) do
      Awfy::GitClient.new(path: empty).stashed_checkout("main") { flunk "block must not run" }
    end

    assert_match(/no commit/, error.message)
  ensure
    FileUtils.remove_entry(empty) if empty
  end

  def test_keeps_the_stash_and_says_so_when_it_cannot_return
    File.write(File.join(@repo, "file.txt"), "work in progress\n")

    error = assert_raises(Awfy::Errors::CheckoutRestoreError) do
      # A tracked file left modified on the other ref blocks the checkout back to main.
      @client.stashed_checkout("feature") { File.write(File.join(@repo, "file.txt"), "left behind\n") }
    end

    assert_match(/main/, error.message)
    assert_match(/stash/, error.message)
    assert_equal 1, stash_count(@repo)
  end
end
