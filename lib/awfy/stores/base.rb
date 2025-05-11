# frozen_string_literal: true

module Awfy
  module Stores
    # Abstract base class for result storage
    # TODO: we could turn this into an Enumerable
    class Base < Literal::Object
      prop :storage_name, String, reader: :private
      prop :retention_policy, RetentionPolicies::Base, reader: :private

      # Abstract methods that subclasses must implement
      def save_result(result)
        raise NoMethodError, "Subclasses must implement save_result"
      end

      def load_result(result_id)
        raise NoMethodError, "Subclasses must implement load_result"
      end

      def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
        raise NoMethodError, "Subclasses must implement query_results"
      end

      def clean_results
        raise NoMethodError, "Subclasses must implement clean_results"
      end

      private

      def retained_by_retention_policy?(result)
        retention_policy.retain?(result)
      end

      # Common method to get result data from a block
      def execute_result_block(&block)
        yield if block_given?
      end

      # Common method to apply filters to query results
      def apply_filters(results, type: nil, group: nil, report: nil, runtime: nil, commit: nil)
        results.select do |result|
          match = true
          match &= result.type == type if type
          match &= result.group == group if group
          match &= result.report == report if report
          match &= result.runtime == Awfy::Runtimes[runtime] if runtime.is_a?(String)
          match &= result.runtime == runtime if runtime.is_a?(Awfy::Runtimes)
          match &= result.commit == commit if commit
          match
        end
      end
    end
  end
end
