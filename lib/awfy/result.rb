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
    prop :commit_hash, _Nilable(String)
    prop :commit_message, _Nilable(String)

    prop :result_id, String, default: -> { generate_new_result_id }
    prop :result_data, _Nilable(Hash)

    def after_initialize
      @result_data = @result_data&.transform_keys(&:to_sym)
    end

    # Factory method to create Result from a serialized hash
    def self.deserialize(hash)
      # Convert integer 1, 0 to true, false for control and baseline
      hash[:control] = true if hash[:control] == 1
      hash[:control] = false if hash[:control] == 0
      hash[:baseline] = true if hash[:baseline] == 1
      hash[:baseline] = false if hash[:baseline] == 0

      hash_with_symbol_keys = hash.transform_keys do |key|
        key.is_a?(String) ? key.to_sym : key
      end

      if hash_with_symbol_keys[:type].is_a?(String)
        hash_with_symbol_keys[:type] = hash_with_symbol_keys[:type].to_sym
      end

      if hash_with_symbol_keys[:timestamp].is_a?(Integer)
        hash_with_symbol_keys[:timestamp] = Time.at(hash_with_symbol_keys[:timestamp])
      end

      Result.new(**hash_with_symbol_keys.slice(*literal_properties.map(&:name)))
    end

    def label
      if result_data && result_data.key?(:label)
        result_data[:label]
      else
        label_from_attributes
      end
    end

    def to_h
      super.compact
    end
    alias_method :serialize, :to_h

    def with(**args)
      self.class.new(**to_h.merge(args))
    end

    def generate_new_result_id
      "#{timestamp}-#{SecureRandom.hex(3)}-#{label_from_attributes}"
    end

    private

    def label_from_attributes
      "#{type}-#{runtime.value}-#{encode_component(branch || "unknown")}-#{encode_component(group_name)}-#{encode_component(report_name)}-#{control? ? "control" : "test"}-#{baseline? ? "baseline" : "result"}"
    end

    def encode_component(component)
      component = component.to_s unless component.is_a?(String)
      URI.encode_www_form_component(component)
    end
  end
end
