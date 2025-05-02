# frozen_string_literal: true

require "fileutils"
require "json"
require "sqlite3"

module Awfy
  # SQLite implementation for result storage
  class SqliteResultStore < ResultStore
    def initialize(options)
      super
      # SQLite library availability is checked at factory level before instantiation

      # Ensure the results directory exists
      FileUtils.mkdir_p(options.results_directory)
      @db_path = File.join(options.results_directory, "awfy_benchmarks.db")

      # Initialize database if it doesn't exist
      setup_database
    end

    def save_result(metadata, &block)
      # Ensure we have a ResultMetadata object
      unless metadata.is_a?(ResultMetadata)
        raise ArgumentError, "Expected ResultMetadata object, got #{metadata.class.name}"
      end
      
      type = metadata.type
      group = metadata.group
      report = metadata.report
      runtime = metadata.runtime

      # Generate data values
      timestamp = metadata.timestamp || Time.now.to_i
      is_temp = !(metadata.save || false)
      branch = metadata.branch || "unknown"

      # Generate a unique identifier for this result
      result_id = "#{timestamp}-#{type}-#{runtime}-#{branch}-#{group}-#{report}"

      # Execute the provided block to get the result data
      result_data = yield if block_given?
      data_json = result_data.to_json

      # Store in database
      db = connect_db

      # Use a transaction for atomicity
      db.transaction do
        # Store the metadata
        db.execute(
          "INSERT INTO metadata (result_id, type, group_name, report_name, runtime,
            timestamp, branch, commit_hash, commit_msg, ruby_version, is_temp)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [
            result_id, type.to_s, group, report, runtime,
            timestamp, branch, metadata.commit, metadata.commit_message,
            metadata.ruby_version, is_temp ? 1 : 0
          ]
        )

        # Store the result data
        db.execute(
          "INSERT INTO results (result_id, data) VALUES (?, ?)",
          [result_id, data_json]
        )
      end

      db.close
      result_id
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      db = connect_db
      db.results_as_hash = true

      # Build the SQL query
      sql = "SELECT m.*, r.data FROM metadata m JOIN results r ON m.result_id = r.result_id WHERE 1=1"
      params = []

      # Add filters
      if type
        sql += " AND m.type = ?"
        params << type.to_s
      end

      if group
        sql += " AND m.group_name = ?"
        params << group
      end

      if report
        sql += " AND m.report_name = ?"
        params << report
      end

      if commit
        sql += " AND m.commit_hash = ?"
        params << commit
      end

      if runtime
        sql += " AND m.runtime = ?"
        params << runtime
      end

      # Execute query
      results = []
      db.execute(sql, params) do |row|
        # Extract result data
        data = JSON.parse(row["data"])

        # Create a metadata hash from row data
        metadata_hash = {
          type: row["type"].to_sym,
          group: row["group_name"],
          report: row["report_name"],
          runtime: row["runtime"],
          timestamp: row["timestamp"],
          branch: row["branch"],
          commit: row["commit_hash"],
          commit_message: row["commit_msg"],
          ruby_version: row["ruby_version"],
          save: row["is_temp"] == 0, # Convert is_temp to save flag
          result_id: row["result_id"],
          result_data: data
        }

        # Create the ResultMetadata object
        metadata_obj = ResultMetadata.new(**metadata_hash)

        # Add to results
        results << metadata_obj
      end

      db.close
      results
    end

    def load_result(result_id)
      db = connect_db
      db.results_as_hash = true

      # Query for both metadata and result data by ID
      result = nil
      db.execute("SELECT m.*, r.data FROM metadata m JOIN results r ON m.result_id = r.result_id WHERE m.result_id = ?", [result_id]) do |row|
        data = JSON.parse(row["data"])
        
        # Create a metadata hash from row data
        metadata_hash = {
          type: row["type"].to_sym,
          group: row["group_name"],
          report: row["report_name"],
          runtime: row["runtime"],
          timestamp: row["timestamp"],
          branch: row["branch"],
          commit: row["commit_hash"],
          commit_message: row["commit_msg"],
          ruby_version: row["ruby_version"],
          save: row["is_temp"] == 0, # Convert is_temp to save flag
          result_id: row["result_id"],
          result_data: data
        }
        
        # Create the ResultMetadata object
        result = ResultMetadata.new(**metadata_hash)
      end

      db.close
      result
    end

    def clean_results(temp_only: true)
      db = connect_db

      if temp_only
        # Delete only temporary results
        db.execute("DELETE FROM results WHERE result_id IN (SELECT result_id FROM metadata WHERE is_temp = 1)")
        db.execute("DELETE FROM metadata WHERE is_temp = 1")
      else
        # Delete all results
        db.execute("DELETE FROM results")
        db.execute("DELETE FROM metadata")
      end

      db.close
    end

    private

    def connect_db
      db = SQLite3::Database.new(@db_path)
      db.busy_timeout = 5000 # 5 seconds timeout for busy database
      db
    end

    def setup_database
      db = SQLite3::Database.new(@db_path)

      # Create tables for metadata and results
      # Note: SQLite doesn't have a specific BOOLEAN type, it uses INTEGER (0=false, 1=true)
      # Also avoid using reserved words like 'commit' as column names
      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS metadata (
          id INTEGER PRIMARY KEY,
          result_id TEXT UNIQUE,
          type TEXT,
          group_name TEXT,
          report_name TEXT,
          runtime TEXT,
          timestamp INTEGER,
          branch TEXT,
          commit_hash TEXT,
          commit_msg TEXT,
          ruby_version TEXT,
          is_temp INTEGER
        );
      SQL

      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS results (
          id INTEGER PRIMARY KEY,
          result_id TEXT UNIQUE,
          data TEXT,
          FOREIGN KEY (result_id) REFERENCES metadata(result_id)
        );
      SQL

      # Create indexes for common queries
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_type ON metadata (type);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_group ON metadata (group_name);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_report ON metadata (report_name);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_commit ON metadata (commit_hash);"

      db.close
    end
  end
end
