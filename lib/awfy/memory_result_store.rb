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

    def save_result(result)
      # Generate an ID for the result
      result_id = "memory-result-#{@next_id}"
      @next_id += 1

      # Get the result data from the block
      data = block_given? ? yield : nil
      # Create complete metadata with result_id and result_data
      complete_metadata = ResultMetadata.new(
        **result.to_h,
        result_id: result_id,
        result_data: data
      )
      @stored_results[result_id] = complete_metadata

      # Return the ID
      result_id
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      @stored_results.values.select do |result|
        (type.nil? || result.type == type) &&
          (group.nil? || result.group == group) &&
          (report.nil? || result.report == report) &&
          (runtime.nil? || result.runtime == runtime) &&
          (commit.nil? || result.commit == commit)
      end
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
