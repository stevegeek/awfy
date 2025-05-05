# frozen_string_literal: true

module Awfy
  module Stores
    # A memory-based implementation of Base for storing benchmark results in memory
    # This is particularly useful for testing and temporary benchmark runs.
    class Memory < Base
      attr_reader :stored_results

      def initialize(options)
        super
        initialize_store
      end

      # Store a benchmark result in memory
      def save_result(metadata, &block)
        validate_metadata!(metadata)

        result_id = generate_memory_result_id
        result_data = execute_result_block(&block)
        @stored_results[result_id] = create_complete_metadata(metadata, result_id, result_data)

        result_id
      end

      # Query stored results with optional filtering
      def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
        # Get all stored results and apply filters from base class
        apply_filters(
          all_stored_results,
          type: type,
          group: group,
          report: report,
          runtime: runtime,
          commit: commit
        )
      end

      # Load a specific result by its ID
      def load_result(result_id)
        @stored_results[result_id]
      end

      # Clean all results from memory
      def clean_results(temp_only: true)
        initialize_store
      end

      private

      def initialize_store
        @stored_results = {}
        @next_id = 1
      end

      def generate_memory_result_id
        result_id = "memory-result-#{@next_id}"
        @next_id += 1
        result_id
      end

      def create_complete_metadata(metadata, result_id, result_data)
        Result.new(
          **metadata.to_h,
          result_id: result_id,
          result_data: result_data
        )
      end

      def all_stored_results
        @stored_results.values
      end
    end
  end
end