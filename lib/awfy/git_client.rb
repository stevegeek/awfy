# frozen_string_literal: true

require "git"

module Awfy
  # GitClient provides a wrapper around the Git gem to interact with Git repositories
  # This class provides a common interface for all Git operations needed in the application
  class GitClient
    # Initialize a new GitClient with a path to a Git repository
    # @param path [String] The path to the Git repository
    def initialize(path)
      @client = Git.open(path)
    end

    # Get the current branch name
    # @return [String] The name of the current branch
    def current_branch
      @client.current_branch
    end

    # Checkout a branch or commit
    # @param reference [String] The branch name or commit hash to checkout
    # @return [Object] The result of the checkout operation
    def checkout(reference)
      @client.checkout(reference)
    end

    # Access to the library command interface
    # This allows executing raw Git commands
    # @return [GitLibWrapper] A wrapper for Git library commands
    def lib
      @lib ||= GitLibWrapper.new(@client.lib)
    end

    # Get a Git object by reference
    # @param reference [String] The reference to look up (e.g., "HEAD", a commit hash, etc.)
    # @return [Git::Object] The requested Git object
    def object(reference)
      @client.object(reference)
    end

    # Get the full SHA hash for a Git reference
    # @param reference [String] The reference to parse (e.g., branch name, commit hash, etc.)
    # @return [String] The full SHA hash for the reference
    def rev_parse(reference)
      lib.command("rev-parse", reference).strip
    end

    # Get a list of commit hashes in the given range
    # @param args [Array<String>] The arguments to pass to rev-list (e.g., "--reverse", "start..end")
    # @return [Array<String>] List of commit hashes
    def rev_list(*args)
      lib.command("rev-list", *args).split("\n")
    end

    # Get commit log information
    # @param args [Array<String>] The arguments to pass to log (e.g., "-1", "--pretty=%s", commit)
    # @return [String] The commit log information
    def log(*args)
      lib.command("log", *args)
    end

    # Get the commit message for a specific commit
    # @param commit [String] The commit hash or reference
    # @param format [String] The format string to use (default: "%s" for subject only)
    # @return [String] The commit message
    def commit_message(commit, format = "%s")
      log("-1", "--pretty=#{format}", commit).strip
    end

    # GitLibWrapper provides access to raw Git commands through the lib interface
    # This is a wrapper around Git::Lib to provide the necessary command methods
    class GitLibWrapper
      # Initialize with a Git::Lib instance
      # @param lib [Git::Lib] The Git library instance
      def initialize(lib)
        @lib = lib
      end

      # Execute a Git command with arguments
      # @param cmd [String] The Git command to execute
      # @param args [Array<String>] The arguments to pass to the command
      # @return [String] The output of the command
      def command(cmd, *args)
        @lib.send(:command, cmd, *args)
      end

      # Create a Git stash with a message
      # @param message [String] The stash message (optional)
      # @return [String] The output of the stash command
      def stash_save(message = nil)
        args = ["stash", "save"]
        args << message if message
        @lib.send(:command, *args)
      end
    end
  end
end
