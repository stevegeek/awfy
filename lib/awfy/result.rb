# frozen_string_literal: true

module Awfy
  # Data object for benchmark result metadata
  class Result < Literal::Data
    prop :type, Symbol
    prop :group, String
    prop :report, String
    prop :runtime, Awfy::Runtimes, default: Awfy::Runtimes::MRI
    prop :timestamp, Time
    prop :branch, String
    prop :commit, String
    prop :commit_message, String
    prop :ruby_version, String, default: RUBY_VERSION
    prop :result_id, String
    prop :result_data, Hash

    def to_h
      super.compact
    end

    # Factory method to create Result from a hash
    def self.from_hash(hash)
      # Valid keys for Result
      valid_keys = %i[type group report runtime timestamp branch commit commit_message
        ruby_version result_id result_data]

      # Convert string keys to symbols
      hash_with_symbol_keys = hash.transform_keys do |key|
        key.is_a?(String) ? key.to_sym : key
      end

      # Filter hash to only include valid keys
      filtered_hash = hash_with_symbol_keys.slice(*valid_keys)

      # Convert type to symbol if present and is a string
      if filtered_hash[:type].is_a?(String)
        filtered_hash[:type] = filtered_hash[:type].to_sym
      end

      # Create the Result object
      new(**filtered_hash)
    end
  end
end
