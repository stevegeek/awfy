# frozen_string_literal: true

require "open3"

module Awfy
  module Runners
    # The awfy command line that repeats one job for one group in a fresh Ruby process.
    #
    # Runners that isolate a group in its own process, or that run it on another git ref,
    # use it so that the child runs with the same settings as the parent. The options that
    # pick a runner (--runner, --compare-with-branch, --commit-range) are never forwarded, so
    # the child runs the group in place.
    class ChildCommand < Literal::Data
      prop :subcommand, _Array(String)
      prop :group_name, String
      prop :config, ::Awfy::Config
      prop :control_commit, _Nilable(String)
      prop :summary, _Boolean, default: true

      # Build the command that runs the same kind of job as `job`.
      def self.for_job(job, **)
        subcommand = case job
        when Jobs::IPS then %w[ips start]
        when Jobs::Memory then %w[memory start]
        when Jobs::RunGroup then %w[suite debug]
        else raise ArgumentError, "#{job.class} jobs cannot run in a separate awfy process"
        end
        new(subcommand:, **)
      end

      def argv
        ["bundle", "exec", "awfy", *subcommand, group_name, *options]
      end

      # Run the command and return its combined standard output and error.
      # Raises when the command exits with an error.
      def run!
        output, status = Open3.capture2e(*argv)
        return output if status.success?

        raise "awfy #{subcommand.join(" ")} '#{group_name}' failed in a separate process " \
          "(exit status #{status.exitstatus}):\n#{output}"
      end

      private

      def options
        options = [
          "--runtime=#{config.runtime}",
          "--test-time=#{config.test_time}",
          "--test-warm-up=#{config.test_warm_up}",
          "--test-iterations=#{config.test_iterations}",
          "--setup-file-path=#{config.setup_file_path}",
          "--tests-path=#{config.tests_path}",
          "--storage-backend=#{config.storage_backend.value}",
          "--storage-name=#{config.storage_name}",
          "--retention-policy=#{config.retention_policy.value}",
          "--retention-days=#{config.retention_days}",
          "--summary-order=#{config.summary_order}",
          "--color=#{config.color.value}"
        ]
        options << (config.quiet? ? "--quiet" : "--verbose=#{config.verbose.value}")
        options << "--target-repo-path=#{config.target_repo_path}" if config.target_repo_path
        options << "--control-commit=#{control_commit}" if control_commit
        options << ((summary && config.show_summary?) ? "--summary" : "--no-summary")
        options
      end
    end
  end
end
