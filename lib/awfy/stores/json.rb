# frozen_string_literal: true

require "fileutils"
require "json"

module Awfy
  module Stores
    # JSON file-based implementation of Base
    class Json < Base
      def initialize(options)
        super
        # Create a subdirectory for the storage name to keep files organized
        @storage_dir = File.join(options.results_directory, storage_name)
        ensure_directory_exists
      end

      def save_result(metadata, &block)
        validate_metadata!(metadata)

        timestamp = metadata.timestamp || Time.now.to_i
        result_id = generate_result_id(metadata)
        result_data = execute_result_block(&block)

        # Get result file and update it
        result_file = metadata_file_path(
          metadata.type,
          metadata.group,
          metadata.report,
          timestamp
        )

        # Create metadata object with result data
        complete_metadata = Result.new(
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
        file_path = File.join(@storage_dir, "#{result_id}.json")
        if File.exist?(file_path)
          result_data = load_json_file(file_path)
          return Result.new(
            **metadata_obj.to_h,
            result_data: result_data
          )
        end

        # If we found metadata but no separate data file, return the metadata as is
        metadata_obj
      end

      def clean_results(ignore_retention: false)
        if ignore_retention
          # If ignoring retention, clean everything
          clean_directory(@storage_dir)
        else
          # Apply retention policy to each file
          apply_retention_policy_to_files(ignore_retention)
        end
      end

      # Apply retention policy to all files in the storage directory
      def apply_retention_policy_to_files(ignore_retention)
        # Only process JSON files
        Dir.glob(File.join(@storage_dir, "*.json")).each do |file_path|
          # Parse the metadata and apply the retention policy

          metadata_json = JSON.parse(File.read(file_path))
          next unless metadata_json.is_a?(Array) && !metadata_json.empty?

          # Convert the first entry to a Result object
          metadata_hash = metadata_json.first
          result = Result.new(**metadata_hash.transform_keys(&:to_sym))

          # Check if the result should be kept based on the retention policy
          unless apply_retention_policy(result, ignore_retention: ignore_retention)
            # Delete the file if it doesn't meet the retention policy
            File.delete(file_path)
          end
        rescue => e
          # Skip files that can't be processed
          warn "Error processing file #{file_path}: #{e.message}"
        end
      end

      private

      def ensure_directory_exists
        FileUtils.mkdir_p(@storage_dir)
      end

      def metadata_file_path(type, group, report, timestamp)
        # Include storage name in the filename to easily identify which storage repository it belongs to
        File.join(
          @storage_dir,
          "#{timestamp}-#{storage_name}-#{type}-#{encode_component(group)}-#{encode_component(report)}.json"
        )
      end

      def find_metadata_files(type, group, report)
        pattern = build_metadata_pattern(type, group, report)
        Dir.glob(pattern)
      end

      def build_metadata_pattern(type, group, report)
        pattern = "#{@storage_dir}/*-#{storage_name}-"
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

        # Convert entries to Result objects and apply filters
        entries = metadata_entries
          .map { |entry| Result.from_hash(entry) }
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
        # Look in the storage directory for metadata files
        Dir.glob("#{@storage_dir}/*.json").each do |file|
          metadata_entries = load_json_file(file)
          next unless metadata_entries

          entry = metadata_entries.find { |e| e["result_id"] == result_id }
          return Result.from_hash(entry) if entry
        rescue
          # Skip files that can't be processed
          next
        end
        nil
      end

      def clean_directory(directory)
        # Make sure the directory exists before trying to clean it
        return unless File.directory?(directory)

        # Delete all JSON files in the directory
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
end
