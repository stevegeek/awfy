# frozen_string_literal: true

module Awfy
  # Abstract base class for result storage
  class ResultStore
    def initialize(options)
      @options = options
    end

    def save_result(metadata, &block)
      raise NotImplementedError, "Subclasses must implement save_result"
    end

    def load_result(result_id)
      raise NotImplementedError, "Subclasses must implement load_result"
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      raise NotImplementedError, "Subclasses must implement"
    end

    def clean_results(temp_only: true)
      raise NotImplementedError, "Subclasses must implement clean_results"
    end
  end
end
