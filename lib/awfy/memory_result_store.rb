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

    def store_result(type, group, report, runtime, metadata)
      # Generate an ID for the result
      result_id = "memory-result-#{@next_id}"
      @next_id += 1

      # Get the result data from the block
      data = block_given? ? yield : nil

      # Store the data for later inspection
      @stored_results[result_id] = {
        type: type,
        group: group,
        report: report,
        runtime: runtime,
        metadata: metadata,
        data: data
      }

      # Return the ID
      result_id
    end

    def get_metadata(type, group = nil, report = nil)
      # Filter stored results based on criteria
      filtered_results = @stored_results.values.select do |result|
        result[:type] == type &&
          (group.nil? || result[:group][:name] == group) &&
          (report.nil? || result[:report] == report)
      end

      # Return metadata for filtered results
      filtered_results.map { |result| result[:metadata] }
    end

    def query_results(query_params = {})
      type = query_params[:type]
      group = query_params[:group]
      report = query_params[:report]
      runtime = query_params[:runtime]

      # Filter stored results based on query parameters
      @stored_results.values.select do |result|
        (type.nil? || result[:type] == type) &&
          (group.nil? || result[:group][:name] == group) &&
          (report.nil? || result[:report] == report) &&
          (runtime.nil? || result[:runtime] == runtime)
      end
    end

    def load_result(result_id)
      # Return the stored result if it exists
      @stored_results[result_id]&.fetch(:data, nil)
    end

    def list_results(type = nil)
      # Group results by type, group, and report
      results = {}

      @stored_results.each do |_, result|
        next if type && result[:type] != type

        result_type = result[:type]
        group_name = result[:group][:name]
        report_name = result[:report]

        results[result_type] ||= {}
        results[result_type][group_name] ||= []
        results[result_type][group_name] << report_name unless results[result_type][group_name].include?(report_name)
      end

      results
    end

    def clean_results(temp_only: true)
      # Memory store doesn't differentiate between temp and permanent
      # Just clear everything if temp_only is false
      @stored_results = {} unless temp_only
    end

    def clear!
      @stored_results = {}
      @next_id = 1
    end
  end
end
