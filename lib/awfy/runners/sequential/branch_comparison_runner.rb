# frozen_string_literal: true

module Awfy
  module Runners
    module Sequential
      # BranchComparisonRunner compares the working tree with another branch
      # (`--compare-with-branch`). For each group it runs the job's command in a fresh Ruby
      # process on the working tree as it is, uncommitted changes included, and then again with
      # the comparison branch checked out. The comparison branch is the control: its results are
      # the baseline of the summary shown after the second run.
      #
      # The working tree is put back as it was afterwards, also when a run fails
      # (see GitClient#preserving_worktree).
      class BranchComparisonRunner < Awfy::Runners::Base
        def run_group(group, &block)
          start!

          unless block_given?
            raise ArgumentError, "No block given to run_group"
          end

          branch = config.compare_with_branch
          # Check both before the first run, so that a bad branch or git state fails fast.
          comparison_commit = resolve_branch(branch)
          git_client.ensure_safe_to_checkout!

          # The job is not called here; it only tells the child which command to run.
          job = yield group

          say "Running group '#{group.name}' on the working tree" if verbose?
          run_in_child_process(ChildCommand.for_job(job, group_name: group.name, config:, summary: false))

          git_client.preserving_worktree("awfy branch comparison auto stash") do
            git_client.checkout!(branch)
            say "Running group '#{group.name}' on branch: #{branch}" if verbose?
            run_in_child_process(ChildCommand.for_job(job, group_name: group.name, config:, control_commit: comparison_commit))
          end
        end

        private

        def resolve_branch(branch)
          git_client.rev_parse(branch)
        rescue Git::FailedError
          raise Errors::GitStateError, "Cannot find '#{branch}' to compare with."
        end
      end
    end
  end
end
