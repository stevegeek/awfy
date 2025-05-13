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

    # Checkout a git reference shashing changes, run a block, and return to the original state
    # @param ref [String] The git reference (branch, commit, etc.) to checkout
    # @yield Execute the given block with the reference checked out
    def stashed_checkout(ref)
      # Save the current state
      before_branch = client.current_branch
      stash_save("awfy auto stash")

      begin
        # Checkout the reference (branch or commit)
        checkout!(ref)
        # Run the block with the ref checked out
        yield
      ensure
        # Return to original branch
        checkout!(before_branch)
        # Pop stashed changes
        stash_pop
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

    private

    def after_initialize
      @client = Git.open(path)
      @client_lib = client.lib
    end

    # Execute a Git command with arguments
    def command(cmd, *args)
      client_lib.send(:command, cmd, *args)
    end

    # Create a Git stash with a message
    def stash_save(message = nil)
      args = ["stash", "save"]
      args << message if message
      client_lib.send(:command, *args)
    end

    def stash_pop
      client_lib.send(:command, "stash", "pop")
    rescue
      # TODO: Handle this error gracefully
      raise StandardError, "Failed to pop stash"
    end

    attr_reader :client, :client_lib
  end
end
