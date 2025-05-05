# frozen_string_literal: true

require "uri"

module Awfy
  module Stores
    # Abstract base class for result storage
    class Base
      def initialize(options)
        @options = options
        @storage_name = options.storage_name || "benchmark_history"
      end
      
      # Get the storage name (could be a database name or directory name)
      def storage_name
        @storage_name
      end

      # Abstract methods that subclasses must implement
      def save_result(metadata, &block)
        raise NotImplementedError, "Subclasses must implement save_result"
      end

      def load_result(result_id)
        raise NotImplementedError, "Subclasses must implement load_result"
      end

      def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
        raise NotImplementedError, "Subclasses must implement query_results"
      end

      def clean_results(temp_only: true)
        raise NotImplementedError, "Subclasses must implement clean_results"
      end

      protected

      # Common method to validate metadata
      def validate_metadata!(metadata)
        unless metadata.is_a?(Result)
          raise ArgumentError, "Expected Result object, got #{metadata.class.name}"
        end
      end

      # Common method to generate a result ID
      def generate_result_id(metadata)
        type = metadata.type
        runtime = metadata.runtime
        group = metadata.group
        report = metadata.report
        timestamp = metadata.timestamp || Time.now.to_i
        branch = metadata.branch || "unknown"

        "#{timestamp}-#{type}-#{runtime}-#{encode_component(branch)}-#{encode_component(group)}-#{encode_component(report)}"
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
          match &= result.runtime == runtime if runtime
          match &= result.commit == commit if commit
          match
        end
      end

      private

      # Helper method to safely encode URI components
      def encode_component(component)
        component = component.to_s unless component.is_a?(String)
        URI.encode_www_form_component(component)
      end
    end
  end
end