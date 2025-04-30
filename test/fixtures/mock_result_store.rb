# frozen_string_literal: true

# A minimal mock implementation for testing
module Awfy
  class ResultStoreFactory
    def self.create(options, backend = :mock)
      MockResultStore.new(options)
    end
  end
  
  class MockResultStore
    def initialize(options)
      @options = options
    end
    
    def store_result(type, group, report, runtime, metadata)
      # Just return a fake file path and ignore storing anything
      # This allows our tests to run without actually needing to save data
      test_file = "/tmp/mock-result-#{Time.now.to_i}.json"
      
      # Get the result data from the block
      data = yield if block_given?
      
      # Return the fake file path
      test_file
    end
    
    def get_metadata(type, group = nil, report = nil)
      # Return empty metadata
      []
    end
    
    def query_results(query_params = {})
      # Return empty results
      []
    end
    
    def load_result(result_id)
      # Return nil, indicating no result found
      nil
    end
  end
end