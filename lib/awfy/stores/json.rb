# frozen_string_literal: true

require "fileutils"
require "json"

module Awfy
  module Stores
    AWFY_RESULT_EXTENSION = ".awfy-result.json"

    # JSON file-based implementation of Base
    class Json < Base
      def after_initialize
        ensure_directory_exists
        @mutex = Mutex.new
      end

      def save_result(result)
        @mutex.synchronize do
          result_id = result.result_id
          
          # Get result file path based on result_id
          result_file = result_file_path(result_id)

          # Prepare hash for JSON storage
          hash_to_store = result.to_h
          if hash_to_store[:timestamp].is_a?(Time)
            hash_to_store[:timestamp] = hash_to_store[:timestamp].to_i
          end
          if hash_to_store[:runtime].is_a?(Awfy::Runtimes)
            hash_to_store[:runtime] = hash_to_store[:runtime].value
          end

          # Load, update, and save result file
          raise "Result ID already exists" if File.exist?(result_file)
          write_json_file(result_file, hash_to_store)

          result_file
        end
      end

      def query_results(type: nil, group_name: nil, report_name: nil, runtime: nil, commit: nil)
        @mutex.synchronize do
          # Find result files matching the criteria
          result_files = Dir.glob(File.join(storage_name, "*#{AWFY_RESULT_EXTENSION}"))
          results = []
          result_files.each do |file|
            # process_result_file(file, results, type, group_name, report_name, runtime, commit)
            entry = load_json_file(file)
            next if entry.nil? || entry.empty?
            results << Result.deserialize(entry)
          end
          apply_filters(
            results,
            type: type,
            group_name: group_name,
            report_name: report_name,
            runtime: runtime,
            commit: commit
          )
        end
      end

      def load_result(result_id)
        @mutex.synchronize do
          # Simply load from the result file path directly
          file_path = result_file_path(result_id)
          break unless File.exist?(file_path)
          result = load_json_file(file_path)
          Result.deserialize(result)
        end
      end

      def clean_results
        @mutex.synchronize do
          apply_retention_policy_to_files
        end
      end

      private

      # Apply retention policy to all files in the storage directory
      def apply_retention_policy_to_files
        # Only process JSON files
        Dir.glob(File.join(storage_name, "*#{AWFY_RESULT_EXTENSION}")).each do |file_path|
          result_hash = JSON.parse(File.read(file_path))
          next unless result_hash

          result = Result.deserialize(result_hash)
          # Check if the result should be kept based on the retention policy
          unless retained_by_retention_policy?(result)
            # Delete the file if it doesn't meet the retention policy
            File.delete(file_path)
          end
        end
      end

      def ensure_directory_exists
        FileUtils.mkdir_p(storage_name)
      end

      def load_json_file(file_path)
        return [] unless File.exist?(file_path)

        JSON.parse(File.read(file_path))
      end

      def write_json_file(file_path, data)
        File.write(file_path, data.to_json)
      end

      def result_file_path(result_id)
        File.join(storage_name, "#{result_id}#{AWFY_RESULT_EXTENSION}")
      end
    end
  end
end
