# frozen_string_literal: true

module Awfy
  # A memory-based implementation of ResultStore
  class MemoryResultStore < ResultStore
    attr_reader :stored_results

    def initialize(options)
      super
      @stored_results = {}
      @next_id = 1
    end

    def save_result(metadata, &block)
      # Validate metadata is a ResultMetadata object
      validate_metadata!(metadata)

      # Generate an ID for the result (using a simplified approach)
      result_id = "memory-result-#{@next_id}"
      @next_id += 1

      # Get the result data from the block
      result_data = execute_result_block(&block)

      # Create complete metadata with result_id and result_data
      complete_metadata = ResultMetadata.new(
        **metadata.to_h,
        result_id: result_id,
        result_data: result_data
      )
      @stored_results[result_id] = complete_metadata

      # Return the ID
      result_id
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      # Use the common filtering logic from the base class
      apply_filters(@stored_results.values, type: type, group: group, report: report, runtime: runtime, commit: commit)
    end

    def load_result(result_id)
      # Return the stored result if it exists
      @stored_results[result_id]
    end

    def clean_results(temp_only: true)
      clear!
    end

    private

    def clear!
      @stored_results = {}
      @next_id = 1
    end
  end
end
