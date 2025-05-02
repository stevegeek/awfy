# frozen_string_literal: true

require "fileutils"
require "json"

module Awfy
  # JSON file-based implementation
  class JsonResultStore < ResultStore
    def initialize(options)
      super
      @temp_dir = options.temp_output_directory
      @results_dir = options.results_directory
      FileUtils.mkdir_p(@temp_dir)
      FileUtils.mkdir_p(@results_dir)
    end

    def save_result(metadata, &block)
      # Validate metadata is a ResultMetadata object
      validate_metadata!(metadata)

      type = metadata.type
      group = metadata.group
      report = metadata.report
      timestamp = metadata.timestamp || Time.now.to_i
      save_to_permanent = metadata.save || false
      output_dir = save_to_permanent ? @results_dir : @temp_dir

      # Generate a unique identifier for this result
      result_id = generate_result_id(metadata)

      # Execute the provided block to get the result data
      result_data = execute_result_block(&block)

      # Metadata file that tracks all results for this type/group/report
      result_file = result_output_file_path(output_dir, type, group, report, timestamp)

      # Load existing metadata if available
      existing_metadata = if File.exist?(result_file)
        JSON.parse(File.read(result_file))
      else
        []
      end

      # Create complete metadata with result_id and output_path
      complete_metadata = ResultMetadata.new(
        **metadata.to_h,
        result_id: result_id,
        result_data: result_data
      )

      # Add entry to existing metadata
      # Convert ResultMetadata to a hash for JSON serialization
      existing_metadata << complete_metadata.to_h

      # Write updated metadata
      File.write(result_file, existing_metadata.to_json)

      result_file
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      # Find metadata files matching the criteria
      metadata_files = []

      # Search in both temp and results directories
      [@temp_dir, @results_dir].each do |dir|
        pattern = "#{dir}/*-awfy-"
        pattern += "#{type}-" if type
        pattern += "*" if !group && !report # If no group/report specified, match all
        pattern += encode_component(group).to_s if group
        pattern += "-#{encode_component(report)}" if report
        pattern += ".json"

        metadata_files.concat(Dir.glob(pattern))
      end

      results = []

      metadata_files.each do |file|
        metadata_entries = JSON.parse(File.read(file))

        # Skip empty files
        next if metadata_entries.empty?

        # Convert entries to ResultMetadata objects and apply filters
        entries = metadata_entries.map { |entry| ResultMetadata.from_hash(entry) }
          .select { |entry| entry.result_data } # Only include entries with result data

        # Apply the filters
        filtered_entries = apply_filters(entries, type: type, group: group, report: report, runtime: runtime, commit: commit)
        results.concat(filtered_entries)
      rescue
        # Skip files that can't be processed
        next
      end

      results
    end

    def load_result(result_id)
      # Find and load the metadata for this result
      metadata_obj = nil

      # Look in both temp and results directories for metadata files
      [@temp_dir, @results_dir].each do |dir|
        Dir.glob("#{dir}/*.json").each do |file|
          metadata_entries = JSON.parse(File.read(file))
          entry = metadata_entries.find { |e| e["result_id"] == result_id }
          if entry
            metadata_obj = ResultMetadata.from_hash(entry)
            break
          end
        rescue
          # Skip files that can't be processed
          next
        end
        break if metadata_obj
      end

      return nil unless metadata_obj

      # Now look for the actual result data in both directories
      [@temp_dir, @results_dir].each do |dir|
        file_path = File.join(dir, "#{result_id}.json")
        if File.exist?(file_path)
          result_data = JSON.parse(File.read(file_path))
          return ResultMetadata.new(
            **metadata_obj.to_h,
            result_data: result_data
          )
        end
      end

      # If we found metadata but no data file, return the metadata with nil data
      metadata_obj
    end

    def clean_results(temp_only: true)
      # Clean temp directory
      Dir.glob("#{@temp_dir}/*.json").each do |file|
        File.delete(file)
      end

      # Clean results directory if requested
      unless temp_only
        Dir.glob("#{@results_dir}/*.json").each do |file|
          File.delete(file)
        end
      end
    end

    private

    def result_output_file_path(output_dir, type, group, report, timestamp)
      File.join(output_dir, "#{timestamp}-awfy-#{type}-#{encode_component(group)}-#{encode_component(report)}.json")
    end
  end
end
