# frozen_string_literal: true

require "fileutils"

module Awfy
  module Runners
    # Base defines the common interface for all runner implementations
    # Runners are responsible for the execution of benchmarks
    # including process management and git operations when needed
    class Base < Literal::Object
      include HasSession

      prop :suite, Suite

      # Run a specific benchmark group
      def run(group_name = nil, &)
        if group_name.nil?
          @suite.groups.each do |group|
            run_group(group, &)
          end
        else
          group = @suite.find_group(group_name)
          run_group(group, &)
        end
      end

      def run_group(group, &)
        raise NoMethodError, "#{self.class} must implement #run_group"
      end


      # Start a benchmark run and set up the environment
      def start!
        @start_time = Time.now.to_i
        # run_cleanup_with_retention_policy
      end
    end
  end
end
