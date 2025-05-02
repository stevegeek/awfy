# frozen_string_literal: true

require "fileutils"
require "json"

module Awfy
  # JSON file-based implementation of ResultStore
  class JsonResultStore < ResultStore
    def initialize(options)
      super
      @temp_dir = options.temp_output_directory
      @results_dir = options.results_directory
      ensure_directories_exist
    end

    def save_result(metadata, &block)
      validate_metadata!(metadata)

      timestamp = metadata.timestamp || Time.now.to_i
      output_dir = metadata.save ? @results_dir : @temp_dir
      result_id = generate_result_id(metadata)
      result_data = execute_result_block(&block)

      # Get result file and update it
      result_file = metadata_file_path(
        output_dir,
        metadata.type,
        metadata.group,
        metadata.report,
        timestamp
      )

      # Create metadata object with result data
      complete_metadata = ResultMetadata.new(
        **metadata.to_h,
        result_id: result_id,
        result_data: result_data
      )

      # Load, update, and save metadata file
      existing_metadata = load_json_file(result_file) || []
      existing_metadata << complete_metadata.to_h
      write_json_file(result_file, existing_metadata)

      result_file
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      # Find metadata files matching the criteria
      metadata_files = find_metadata_files(type, group, report)
      results = []

      metadata_files.each do |file|
        process_metadata_file(file, results, type, group, report, runtime, commit)
      end

      results
    end

    def load_result(result_id)
      metadata_obj = find_metadata_by_id(result_id)
      return nil unless metadata_obj

      # Check for separate result data file (not used currently but kept for compatibility)
      [@temp_dir, @results_dir].each do |dir|
        file_path = File.join(dir, "#{result_id}.json")
        if File.exist?(file_path)
          result_data = load_json_file(file_path)
          return ResultMetadata.new(
            **metadata_obj.to_h,
            result_data: result_data
          )
        end
      end

      # If we found metadata but no separate data file, return the metadata as is
      metadata_obj
    end

    def clean_results(temp_only: true)
      # Clean temp directory
      clean_directory(@temp_dir)

      # Clean results directory if requested
      clean_directory(@results_dir) unless temp_only
    end

    private

    def ensure_directories_exist
      FileUtils.mkdir_p(@temp_dir)
      FileUtils.mkdir_p(@results_dir)
    end

    def metadata_file_path(output_dir, type, group, report, timestamp)
      File.join(
        output_dir,
        "#{timestamp}-awfy-#{type}-#{encode_component(group)}-#{encode_component(report)}.json"
      )
    end

    def find_metadata_files(type, group, report)
      metadata_files = []

      # Search in both temp and results directories
      [@temp_dir, @results_dir].each do |dir|
        pattern = build_metadata_pattern(dir, type, group, report)
        metadata_files.concat(Dir.glob(pattern))
      end

      metadata_files
    end

    def build_metadata_pattern(dir, type, group, report)
      pattern = "#{dir}/*-awfy-"
      pattern += "#{type}-" if type
      pattern += "*" if !group && !report # If no group/report specified, match all
      pattern += encode_component(group).to_s if group
      pattern += "-#{encode_component(report)}" if report
      pattern += ".json"
      pattern
    end

    def process_metadata_file(file, results, type, group, report, runtime, commit)
      metadata_entries = load_json_file(file)
      return if metadata_entries.nil? || metadata_entries.empty?

      # Convert entries to ResultMetadata objects and apply filters
      entries = metadata_entries
        .map { |entry| ResultMetadata.from_hash(entry) }
        .select { |entry| entry.result_data } # Only include entries with result data

      # Apply the filters
      filtered_entries = apply_filters(entries,
        type: type,
        group: group,
        report: report,
        runtime: runtime,
        commit: commit)
      results.concat(filtered_entries)
    end

    def find_metadata_by_id(result_id)
      # Look in both temp and results directories for metadata files
      [@temp_dir, @results_dir].each do |dir|
        Dir.glob("#{dir}/*.json").each do |file|
          metadata_entries = load_json_file(file)
          next unless metadata_entries

          entry = metadata_entries.find { |e| e["result_id"] == result_id }
          return ResultMetadata.from_hash(entry) if entry
        rescue
          # Skip files that can't be processed
          next
        end
      end
      nil
    end

    def clean_directory(directory)
      Dir.glob("#{directory}/*.json").each do |file|
        File.delete(file)
      end
    end

    def load_json_file(file_path)
      return [] unless File.exist?(file_path)

      JSON.parse(File.read(file_path))
    end

    def write_json_file(file_path, data)
      File.write(file_path, data.to_json)
    end
  end
end
