# frozen_string_literal: true

require "git"

module Awfy
  # GitClient provides a wrapper around the Git gem to interact with Git repositories
  # This class provides a common interface for all Git operations needed in the application
  class GitClient < Literal::Object
    prop :path, String, reader: :private

    # Get the current branch name
    # @return [String] The name of the current branch
    def current_branch
      client.current_branch
    end

    # Checkout a branch or commit
    # @param reference [String] The branch name or commit hash to checkout
    # @return [Object] The result of the checkout operation
    def checkout!(reference)
      client.checkout(reference)
    end

    # Check out a git reference, run the block, and return to the original state.
    # See #preserving_worktree for what is restored and when it refuses to start.
    # @param ref [String] The git reference (branch, commit, etc.) to check out
    # @yield Execute the given block with the reference checked out
    def stashed_checkout(ref)
      preserving_worktree do
        checkout!(ref)
        yield
      end
    end

    # Run a block that may check out other refs, then put the working tree back as it was:
    # uncommitted changes to tracked files are stashed first, and afterwards the original
    # branch (or commit, when HEAD is detached) is checked out and the stash is popped. The
    # restore also runs when the block raises.
    #
    # Raises Errors::UnsafeCheckoutError before changing anything when HEAD has no commit, or
    # when a rebase, merge, cherry-pick, revert or bisect is in progress, or when files are
    # unmerged. Raises Errors::CheckoutRestoreError when the restore itself fails; the message
    # names the stash that still holds the changes.
    # @param stash_message [String] The message for the stash entry
    # @yield [original_ref] The branch name, or commit sha when detached, to return to
    def preserving_worktree(stash_message = "awfy auto stash")
      original_ref = ensure_safe_to_checkout!
      stash_sha = stash_tracked_changes(stash_message)
      begin
        yield original_ref
      ensure
        restore_worktree(original_ref, stash_sha)
      end
    end

    # Get a Git object by reference
    # @param reference [String] The reference to look up (e.g., "HEAD", a commit hash, etc.)
    # @return [Git::Object] The requested Git object
    def object(reference)
      client.object(reference)
    end

    # Get the full SHA hash for a Git reference
    # @param reference [String] The reference to parse (e.g., branch name, commit hash, etc.)
    # @return [String] The full SHA hash for the reference
    def rev_parse(reference)
      command("rev-parse", reference).strip
    end

    # Get a list of commit hashes in the given range
    # @param args [Array<String>] The arguments to pass to rev-list (e.g., "--reverse", "start..end")
    # @return [Array<String>] List of commit hashes
    def rev_list(*args)
      command("rev-list", *args).split("\n")
    end

    # Get commit log information
    # @param args [Array<String>] The arguments to pass to log (e.g., "-1", "--pretty=%s", commit)
    # @return [String] The commit log information
    def log(*args)
      command("log", *args)
    end

    # Get the commit message for a specific commit
    # @param commit [String] The commit hash or reference
    # @param format [String] The format string to use (default: "%s" for subject only)
    # @return [String] The commit message
    def commit_message(commit, format = "%s")
      log("-1", "--pretty=#{format}", commit).strip
    end

    # Branch, HEAD sha and subject, or nil values when git is unusable here (no repository,
    # no git binary, an unreadable .git). Never raises.
    # @return [Hash] {branch:, commit_hash:, commit_message:}
    def info
      {branch: current_branch, commit_hash: rev_parse("HEAD"), commit_message: commit_message("HEAD")}
    rescue => e
      warn "awfy: git information unavailable (#{e.class}: #{e.message})" if ENV["AWFY_DEBUG"]
      {branch: nil, commit_hash: nil, commit_message: nil}
    end

    # Files in the git directory that mark an operation the user has not finished yet.
    IN_PROGRESS_MARKERS = {
      "rebase-merge" => "a rebase",
      "rebase-apply" => "a rebase or `git am`",
      "MERGE_HEAD" => "a merge",
      "CHERRY_PICK_HEAD" => "a cherry-pick",
      "REVERT_HEAD" => "a revert",
      "BISECT_LOG" => "a bisect"
    }.freeze

    # Checks that the working tree can be stashed, switched and put back, and returns the ref
    # to return to: the branch name, or the commit sha when HEAD is detached.
    # Raises Errors::UnsafeCheckoutError when it cannot (see #preserving_worktree).
    def ensure_safe_to_checkout!
      head_sha = begin
        rev_parse("HEAD")
      rescue Git::FailedError
        raise Errors::UnsafeCheckoutError, "Cannot check out other refs: HEAD has no commit yet, so there is nothing to return to."
      end

      git_dir = command("rev-parse", "--absolute-git-dir").strip
      IN_PROGRESS_MARKERS.each do |marker, operation|
        next unless File.exist?(File.join(git_dir, marker))
        raise Errors::UnsafeCheckoutError, "Cannot check out other refs while #{operation} is in progress. Finish or abort it first."
      end

      unless command("diff", "--name-only", "--diff-filter=U").strip.empty?
        raise Errors::UnsafeCheckoutError, "Cannot check out other refs while there are unmerged files. Resolve them first."
      end

      branch = command("rev-parse", "--abbrev-ref", "HEAD").strip
      (branch == "HEAD") ? head_sha : branch
    end

    private

    # Stashes changes to tracked files (staged and unstaged) and returns the stash commit sha,
    # or nil when there was nothing to stash. Untracked files stay in place: results stores
    # often live untracked inside the repository and must survive the checkouts.
    def stash_tracked_changes(message)
      return nil if command("status", "--porcelain", "--untracked-files=no").strip.empty?

      command("stash", "push", "--message", message)
      rev_parse("refs/stash")
    end

    def restore_worktree(original_ref, stash_sha)
      begin
        checkout!(original_ref)
      rescue Git::FailedError => e
        kept = stash_sha ? " Your uncommitted changes are kept in stash #{stash_sha} (see `git stash list`)." : ""
        raise Errors::CheckoutRestoreError, "Could not check out '#{original_ref}' again: #{git_error_detail(e)}.#{kept}"
      end

      pop_stash(stash_sha) if stash_sha
    end

    # Pops the stash entry with the given sha, wherever it now sits in the stash list, so that
    # entries pushed by others in the meantime are left alone.
    def pop_stash(stash_sha)
      index = command("stash", "list", "--format=%H").split("\n").index(stash_sha)
      unless index
        raise Errors::CheckoutRestoreError, "The stash awfy made (#{stash_sha}) is no longer in the stash list; apply it with `git stash apply #{stash_sha}`."
      end

      command("stash", "pop", "--index", "stash@{#{index}}")
    rescue Git::FailedError => e
      raise Errors::CheckoutRestoreError, "Could not re-apply your uncommitted changes: #{git_error_detail(e)}. They are kept in stash #{stash_sha} (see `git stash list`)."
    end

    def git_error_detail(error)
      detail = error.respond_to?(:result) ? error.result.stderr.to_s.strip : ""
      detail.empty? ? error.message : detail
    end

    # Opened on first use so that commands which never need git work outside a repository.
    def client
      @client ||= Git.open(path)
    end

    def client_lib
      @client_lib ||= client.lib
    end

    # Execute a Git command with arguments
    def command(cmd, *args)
      client_lib.send(:command, cmd, *args)
    end
  end
end
