# frozen_string_literal: true

module Awfy
  # Abstract base class for result storage
  class ResultStore
    def initialize(options)
      @options = options
    end

    # Store a benchmark result
    # @param type [Symbol] The type of benchmark (ips, memory, etc.)
    # @param group [String] The group name
    # @param report [String] The report name
    # @param runtime [String] The runtime used (mri, yjit)
    # @param metadata [ResultMetadata] Metadata object for the result
    # @yield A block that returns the benchmark result data
    # @return [String] The ID or path of the stored result
    def store_result(type, group, report, runtime, metadata, &block)
      raise NotImplementedError, "Subclasses must implement store_result"
    end

    # Retrieve results matching the criteria
    # @param query_params [Hash] Query parameters to filter results
    # @return [Array<Hash>] Array of result objects with metadata and data
    def query_results(query_params = {})
      raise NotImplementedError, "Subclasses must implement query_results"
    end

    # Load a specific result by ID
    # @param result_id [String] The ID of the result to load
    # @return [Object, nil] The result data or nil if not found
    def load_result(result_id)
      raise NotImplementedError, "Subclasses must implement load_result"
    end

    # Get all metadata for results of a specific type/group/report combination
    # @param type [Symbol] The type of benchmark (ips, memory, etc.)
    # @param group [String, nil] The group name (optional)
    # @param report [String, nil] The report name (optional)
    # @return [Array<Hash>] Array of metadata objects
    def get_metadata(type, group = nil, report = nil)
      raise NotImplementedError, "Subclasses must implement get_metadata"
    end

    # List available result groups
    # @param type [Symbol, nil] The type of benchmark to filter by (optional)
    # @return [Hash] Nested hash of available results
    def list_results(type = nil)
      raise NotImplementedError, "Subclasses must implement list_results"
    end

    # Clean up results
    # @param temp_only [Boolean] Whether to clean only temporary results
    def clean_results(temp_only: true)
      raise NotImplementedError, "Subclasses must implement clean_results"
    end

    # Create a ResultMetadata object from a hash
    # @param metadata_hash [Hash] The metadata as a hash
    # @return [ResultMetadata] The metadata as a ResultMetadata object
    def create_metadata(metadata_hash)
      # Convert string keys to symbols if necessary
      metadata = if metadata_hash.keys.first.is_a?(String)
        metadata_hash.transform_keys(&:to_sym)
      else
        metadata_hash
      end

      # Create a hash with only the keys that ResultMetadata accepts
      valid_keys = ResultMetadata.members
      filtered_metadata = metadata.select { |k, _| valid_keys.include?(k) }

      # Create a new ResultMetadata with default nil values for missing keys
      defaults = valid_keys.map { |k| [k, nil] }.to_h
      ResultMetadata.new(**defaults.merge(filtered_metadata))
    end
  end
end
