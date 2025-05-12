# frozen_string_literal: true

require "uri"
require "securerandom"

module Awfy
  # Data object for benchmark result metadata
  class Result < Literal::Data
    prop :ruby_version, String, default: RUBY_VERSION

    prop :type, Symbol
    prop :baseline, _Boolean, default: false, predicate: :public
    prop :control, _Boolean, default: false, predicate: :public

    prop :group_name, String
    prop :report_name, String

    prop :runtime, Awfy::Runtimes, default: Awfy::Runtimes::MRI, &Awfy::Runtimes
    prop :timestamp, Time do
      Time.at(it)
    end

    prop :branch, _Nilable(String)
    prop :commit, _Nilable(String)
    prop :commit_message, _Nilable(String)

    prop :result_id, String, default: -> { generate_new_result_id }
    prop :result_data, _Nilable(Hash)

    # Factory method to create Result from a serialized hash
    def self.deserialize(hash)
      valid_keys = %i[type control baseline group_name report_name runtime timestamp branch commit commit_message
        ruby_version result_id result_data]

      # Convert integer 1, 0 to true, false for control and baseline
      hash[:control] = true if hash[:control] == 1
      hash[:control] = false if hash[:control] == 0
      hash[:baseline] = true if hash[:baseline] == 1
      hash[:baseline] = false if hash[:baseline] == 0

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

      # Convert timestamp to Time if it's an integer
      if filtered_hash[:timestamp].is_a?(Integer)
        filtered_hash[:timestamp] = Time.at(filtered_hash[:timestamp])
      end

      Result.new(**filtered_hash)
    end

    def to_h
      super.compact
    end
    alias_method :serialize, :to_h

    def generate_new_result_id
      "#{timestamp}-#{SecureRandom.hex(3)}-#{type}-#{runtime.value}-#{encode_component(branch || "unknown")}-#{encode_component(group_name)}-#{encode_component(report_name)}-#{control? ? "control" : "test"}-#{baseline? ? "baseline" : "result"}"
    end

    private

    def encode_component(component)
      component = component.to_s unless component.is_a?(String)
      URI.encode_www_form_component(component)
    end
  end
end
