# frozen_string_literal: true

module Awfy
  module Stores
    # A memory-based implementation of Base for storing benchmark results in memory
    # This is particularly useful for testing and temporary benchmark runs.
    class Memory < Base
      attr_reader :stored_results

      def after_initialize
        initialize_store
        @mutex = Mutex.new
      end

      # Store a benchmark result in memory
      def save_result(result)
        @mutex.synchronize do
          result_id = result.result_id
          @stored_results[result_id] = result
          result_id
        end
      end

      # Query stored results with optional filtering
      def query_results(type: nil, group_name: nil, report_name: nil, test_name: nil, runtime: nil, commit_hash: nil)
        @mutex.synchronize do
          # Get all stored results and apply filters from base class
          apply_filters(
            all_stored_results,
            type: type,
            group_name: group_name,
            report_name: report_name,
            test_name: test_name,
            runtime: runtime,
            commit: commit_hash
          )
        end
      end

      # Load a specific result by its ID
      def load_result(result_id)
        @mutex.synchronize { @stored_results[result_id] }
      end

      # Clean results from memory based on retention policy
      def clean_results
        @mutex.synchronize do
          # Apply retention policy to each result
          results_to_keep = {}

          @stored_results.each do |result_id, result|
            if retained_by_retention_policy?(result)
              # Keep results that match the retention policy
              results_to_keep[result_id] = result
            end
          end

          # Replace stored results with the filtered list
          @stored_results = results_to_keep
        end
      end

      private

      def initialize_store
        @stored_results = {}
      end

      def all_stored_results
        @stored_results.values
      end
    end
  end
end
