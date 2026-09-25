# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"

# Builds small throwaway git repositories so that tests can exercise real checkouts and stashes.
module GitRepoHelper
  # Creates a repository with one commit on `main` holding `file.txt` ("main\n") and returns its path.
  def create_git_repo
    dir = File.realpath(Dir.mktmpdir("awfy_git_repo"))
    git(dir, "init", "-q", "-b", "main")
    git(dir, "config", "user.name", "Awfy Test")
    git(dir, "config", "user.email", "awfy@example.com")
    git(dir, "config", "commit.gpgsign", "false")
    commit_file(dir, "file.txt", "main\n", "Initial commit")
    dir
  end

  # Writes and commits one file, returning the new commit's sha.
  def commit_file(dir, name, content, message)
    FileUtils.mkdir_p(File.dirname(File.join(dir, name)))
    File.write(File.join(dir, name), content)
    git(dir, "add", name)
    git(dir, "commit", "-q", "-m", message)
    git(dir, "rev-parse", "HEAD")
  end

  # Runs git in the repository and returns its stripped standard output. Raises when git fails.
  def git(dir, *args)
    out, err, status = Open3.capture3("git", "-C", dir, *args)
    raise "git #{args.join(" ")} failed: #{err}" unless status.success?
    out.strip
  end

  # The checked out branch, or the commit sha when HEAD is detached.
  def head_ref(dir)
    ref = git(dir, "rev-parse", "--abbrev-ref", "HEAD")
    (ref == "HEAD") ? git(dir, "rev-parse", "HEAD") : ref
  end

  def stash_count(dir)
    git(dir, "stash", "list").lines.size
  end

  def read_file(dir, name)
    File.read(File.join(dir, name))
  end
end
