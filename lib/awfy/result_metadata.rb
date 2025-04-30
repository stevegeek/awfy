# frozen_string_literal: true

module Awfy
  # Data object for benchmark result metadata
  ResultMetadata = Data.define(
    :type,
    :group,
    :report,
    :runtime,
    :timestamp,
    :branch,
    :commit,
    :commit_message,
    :ruby_version,
    :save,
    :result_id,
    :result_data
  ) do
    def to_h
      super.compact
    end
  end
end
