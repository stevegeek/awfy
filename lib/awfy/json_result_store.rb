# frozen_string_literal: true

require "fileutils"
require "uri"
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

    def store_result(type, group, report, runtime, metadata, &block)
      # Ensure we have a ResultMetadata object
      unless metadata.is_a?(ResultMetadata)
        raise ArgumentError, "Expected ResultMetadata object, got #{metadata.class.name}"
      end

      timestamp = metadata.timestamp || Time.now.to_i
      save_to_permanent = metadata.save || false
      output_dir = save_to_permanent ? @results_dir : @temp_dir

      # Generate a unique identifier for this result
      result_id = generate_result_id(type, runtime, group, report, timestamp, metadata.branch)

      # Execute the provided block to get the result data
      result_data = yield if block_given?

      # File path for the actual result data
      result_file = File.join(output_dir, "#{result_id}.json")

      # Save the actual benchmark result data
      File.write(result_file, result_data.to_json)

      # Metadata file that tracks all results for this type/group/report
      metadata_file = File.join(output_dir, "#{timestamp}-awfy-#{type}-#{URI.encode_www_form_component(group)}-#{URI.encode_www_form_component(report)}.json")

      # Load existing metadata if available
      existing_metadata = if File.exist?(metadata_file)
        JSON.parse(File.read(metadata_file))
      else
        []
      end

      # Create complete metadata with result_id and output_path
      complete_metadata = ResultMetadata.new(
        **metadata.to_h,
        result_id: result_id,
        output_path: result_file
      )

      # Add entry to existing metadata
      # Convert ResultMetadata to a hash for JSON serialization
      existing_metadata << complete_metadata.to_h

      # Write updated metadata
      File.write(metadata_file, existing_metadata.to_json)

      result_file
    end

    def query_results(query_params = {})
      type = query_params[:type]
      group = query_params[:group]
      report = query_params[:report]
      commit = query_params[:commit]
      runtime = query_params[:runtime]

      # Find metadata files matching the criteria
      metadata_files = []

      # Search in both temp and results directories
      [@temp_dir, @results_dir].each do |dir|
        pattern = "#{dir}/*-awfy-"
        pattern += "#{type}-" if type
        pattern += "*" if !group && !report # If no group/report specified, match all
        pattern += "#{URI.encode_www_form_component(group)}" if group
        pattern += "-#{URI.encode_www_form_component(report)}" if report
        pattern += ".json"

        metadata_files.concat(Dir.glob(pattern))
      end

      results = []

      metadata_files.each do |file|
        metadata_entries = JSON.parse(File.read(file))

        # Filter by criteria
        filtered_entries = metadata_entries.select do |entry|
          matches = true
          matches &= entry["runtime"] == runtime if runtime
          matches &= entry["commit"] == commit if commit
          matches
        end

        filtered_entries.each do |entry|
          # Load the actual result data if the file exists
          if File.exist?(entry["output_path"])
            result_data = JSON.parse(File.read(entry["output_path"]))

            # Convert the metadata hash to a ResultMetadata object
            metadata_obj = create_metadata(entry)

            results << {
              metadata: metadata_obj,
              data: result_data
            }
          end
        end
      rescue
        # Skip files that can't be processed
        next
      end

      results
    end

    def load_result(result_id)
      # Look in both directories
      [@temp_dir, @results_dir].each do |dir|
        file_path = File.join(dir, "#{result_id}.json")
        if File.exist?(file_path)
          return JSON.parse(File.read(file_path))
        end
      end

      nil
    end

    def get_metadata(type, group = nil, report = nil)
      metadata = []

      # Search in both temp and results directories
      [@temp_dir, @results_dir].each do |dir|
        pattern = "#{dir}/*-awfy-#{type}"
        pattern += "-#{URI.encode_www_form_component(group)}" if group
        pattern += "-#{URI.encode_www_form_component(report)}" if report
        pattern += ".json"

        Dir.glob(pattern).each do |file|
          entries = JSON.parse(File.read(file))
          metadata.concat(entries)
        rescue
          # Skip files that can't be processed
          next
        end
      end

      metadata
    end

    def list_results(type = nil)
      results = {}

      # Search in both temp and results directories
      [@temp_dir, @results_dir].each do |dir|
        pattern = "#{dir}/*-awfy-"
        pattern += "#{type}-" if type
        pattern += "*.json"

        Dir.glob(pattern).each do |file|
          basename = File.basename(file)
          parts = basename.split("-")

          # Extract type, group, report from filename
          file_type = parts[2]
          next if type && file_type != type

          group_report = parts[3..-1].join("-").sub(".json", "")
          group, report = group_report.split("-")

          # Decode URI components
          group = URI.decode_www_form_component(group) if group
          report = URI.decode_www_form_component(report) if report

          # Initialize nested structure
          results[file_type] ||= {}
          results[file_type][group] ||= []
          results[file_type][group] << report unless results[file_type][group].include?(report)
        rescue
          # Skip files that can't be processed
          next
        end
      end

      results
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

    def generate_result_id(type, runtime, group, report, timestamp, branch)
      branch ||= "unknown"
      "#{timestamp}-#{type}-#{runtime}-#{URI.encode_www_form_component(branch)}-#{URI.encode_www_form_component(group)}-#{URI.encode_www_form_component(report)}"
    end
  end
end
