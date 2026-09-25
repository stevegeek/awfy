# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # CommitRangeRunner runs benchmarks across a range of commits
      # Each commit is checked out and run in a fresh Ruby process for clean results.
      # The working tree is put back as it was afterwards, also when a run fails
      # (see GitClient#preserving_worktree).
      class CommitRangeRunner < Awfy::Runners::Base
        # Run a specific group across all commits
        # @param group [Awfy::Suites::Group] The group to run
        # @yield [Awfy::Suites::Group] Yields the group to create a job
        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          start_commit, end_commit = parse_commit_range(config.commit_range)

          # The job is not called here; it only tells the child which command to run.
          job = yield group

          git_client.preserving_worktree("awfy commit range auto stash") do
            commit_list = get_commits_in_range(start_commit, end_commit)
            control_commit = resolve_control_commit(commit_list)

            commit_list.each do |commit|
              run_on_commit(commit, job, group, control_commit)
            end
          end
        end

        private

        # The control commit given in the config as a full sha, or the first commit of the range
        def resolve_control_commit(commit_list)
          if config.control_commit.nil? || config.control_commit.empty?
            commit_list.first.tap do |commit|
              say "Using first commit as control: #{commit.slice(0, 8)}" if verbose?
            end
          else
            git_client.rev_parse(config.control_commit).tap do |commit|
              say "Using specified commit as control: #{commit.slice(0, 8)}" if verbose?
            end
          end
        end

        # Parse commit range string into start and end commits
        # @param range_str [String] Commit range string (e.g., "main..HEAD" or "abc123..def456")
        # @return [Array<String>] Array with [start_commit, end_commit]
        def parse_commit_range(range_str)
          raise ArgumentError, "commit_range option is required for commit_range runner" if range_str.nil? || range_str.empty?

          # Split on .. or ...
          parts = range_str.split(/\.{2,3}/)

          if parts.length == 1
            # Single commit provided, use it as both start and end
            [parts[0], parts[0]]
          elsif parts.length == 2
            # Range provided
            start_commit = parts[0].empty? ? "HEAD" : parts[0]
            end_commit = parts[1].empty? ? "HEAD" : parts[1]
            [start_commit, end_commit]
          else
            raise ArgumentError, "Invalid commit range format: #{range_str}"
          end
        end

        # Get the list of commits in the specified range
        # @param start_commit [String] The starting commit of the range
        # @param end_commit [String] The ending commit of the range
        # @return [Array<String>] List of commit hashes in the range
        def get_commits_in_range(start_commit, end_commit)
          # Resolve commit hashes first
          start_hash = git_client.rev_parse(start_commit)
          end_hash = git_client.rev_parse(end_commit)

          # If start and end are the same, return just that commit
          if start_hash == end_hash
            return [start_hash]
          end

          # Check if start_hash is a root commit (has no parent)
          is_root_commit = begin
            git_client.rev_parse("#{start_hash}^")
            false
          rescue
            true
          end

          # Get all commits in the range (inclusive of start and end)
          if is_root_commit
            # For root commits, we can't use ^, so just use the range directly
            # and manually include the start commit
            commit_range = "#{start_hash}..#{end_hash}"
            commits = git_client.rev_list("--reverse", commit_range)
            commits.unshift(start_hash)
          else
            # For non-root commits, use ^ to include the start commit
            commit_range = "#{start_hash}^..#{end_hash}"
            commits = git_client.rev_list("--reverse", commit_range)

            # If start commit wasn't included due to the ^ operator, add it back
            start_index = commits.index(start_hash)
            if start_index.nil?
              commits.unshift(start_hash)
            end
          end

          commits
        end

        # Check out one commit and run the job's command for the group in a fresh process, so
        # that the code of that commit is loaded rather than the code already in memory.
        def run_on_commit(commit, job, group, control_commit)
          git_client.checkout!(commit)

          if verbose?
            say "Running benchmarks on commit: #{commit.slice(0, 8)} - #{git_client.commit_message(commit)}"
          end

          run_in_child_process(ChildCommand.for_job(job, group_name: group.name, config:, control_commit:))
        end
      end
    end
  end
end
