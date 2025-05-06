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
          groups.each_value do |group|
            run_group(group, &)
          end
        else
          group = groups[group_name]
          raise ArgumentError, "Group '#{group_name}' not found" unless group
          run_group(group, &)
        end
      end

      def run_group(group, &)
        raise NoMethodError, "#{self.class} must implement #run_group"
      end
      
      private

      def groups
        @suite.groups
      end

      # Start a benchmark run and set up the environment
      def start!
        @start_time = Time.now.to_i
        session.say_configuration
        # run_cleanup_with_retention_policy
      end
    end
  end
end
