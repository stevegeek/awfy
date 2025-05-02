# frozen_string_literal: true

require "fileutils"
require "json"
require "sqlite3"

module Awfy
  # SQLite implementation for result storage
  class SqliteResultStore < ResultStore
    # SQL query parts
    JOIN_TABLES_SQL = "SELECT m.*, r.data FROM metadata m JOIN results r ON m.result_id = r.result_id"
    METADATA_TABLE_SCHEMA = <<~SQL
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

    RESULTS_TABLE_SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS results (
        id INTEGER PRIMARY KEY,
        result_id TEXT UNIQUE,
        data TEXT,
        FOREIGN KEY (result_id) REFERENCES metadata(result_id)
      );
    SQL

    def initialize(options)
      super
      # SQLite library availability is checked at factory level before instantiation
      ensure_results_directory(options.results_directory)
      @db_path = File.join(options.results_directory, "awfy_benchmarks.db")
      setup_database
    end

    def save_result(metadata, &block)
      validate_metadata!(metadata)

      # Prepare data for storage
      result_id = generate_result_id(metadata)
      result_data = execute_result_block(&block)
      is_temp = !metadata.save

      # Store result in database
      with_database_connection do |db|
        store_benchmark_result(db, metadata, result_id, result_data, is_temp)
      end

      result_id
    end

    def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
      results = []

      with_database_connection do |db|
        # Setup db to return results as hashes
        db.results_as_hash = true

        # Build and execute the query
        sql, params = build_query_sql(type, group, report, runtime, commit)
        db.execute(sql, params) do |row|
          results << create_metadata_from_row(row)
        end
      end

      results
    end

    def load_result(result_id)
      result = nil

      with_database_connection do |db|
        db.results_as_hash = true

        # Build the query to find a specific result
        sql = "#{JOIN_TABLES_SQL} WHERE m.result_id = ?"
        db.execute(sql, [result_id]) do |row|
          result = create_metadata_from_row(row)
        end
      end

      result
    end

    def clean_results(temp_only: true)
      with_database_connection do |db|
        if temp_only
          # Delete only temporary results
          db.execute("DELETE FROM results WHERE result_id IN (SELECT result_id FROM metadata WHERE is_temp = 1)")
          db.execute("DELETE FROM metadata WHERE is_temp = 1")
        else
          # Delete all results
          db.execute("DELETE FROM results")
          db.execute("DELETE FROM metadata")
        end
      end
    end

    private

    def ensure_results_directory(directory)
      FileUtils.mkdir_p(directory)
    end

    def with_database_connection
      db = connect_db
      begin
        yield db
      ensure
        db.close
      end
    end

    def connect_db
      db = SQLite3::Database.new(@db_path)
      db.busy_timeout = 5000 # 5 seconds timeout for busy database
      db
    end

    def setup_database
      with_database_connection do |db|
        # Create tables
        db.execute(METADATA_TABLE_SCHEMA)
        db.execute(RESULTS_TABLE_SCHEMA)

        # Create indexes for common queries
        create_indexes(db)
      end
    end

    def create_indexes(db)
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_type ON metadata (type);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_group ON metadata (group_name);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_report ON metadata (report_name);"
      db.execute "CREATE INDEX IF NOT EXISTS idx_metadata_commit ON metadata (commit_hash);"
    end

    def store_benchmark_result(db, metadata, result_id, result_data, is_temp)
      # Use a transaction for atomicity
      db.transaction do
        store_metadata(db, metadata, result_id, is_temp)
        store_result_data(db, result_id, result_data)
      end
    end

    def store_metadata(db, metadata, result_id, is_temp)
      timestamp = metadata.timestamp || Time.now.to_i

      db.execute(
        "INSERT INTO metadata (result_id, type, group_name, report_name, runtime,
          timestamp, branch, commit_hash, commit_msg, ruby_version, is_temp)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          result_id, metadata.type.to_s, metadata.group, metadata.report, metadata.runtime,
          timestamp, metadata.branch, metadata.commit, metadata.commit_message,
          metadata.ruby_version, is_temp ? 1 : 0
        ]
      )
    end

    def store_result_data(db, result_id, result_data)
      data_json = result_data.to_json
      db.execute(
        "INSERT INTO results (result_id, data) VALUES (?, ?)",
        [result_id, data_json]
      )
    end

    def build_query_sql(type, group, report, runtime, commit)
      sql = "#{JOIN_TABLES_SQL} WHERE 1=1"
      params = []

      # Add filters conditionally
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

      [sql, params]
    end

    def create_metadata_from_row(row)
      # Parse result data from JSON
      data = JSON.parse(row["data"])

      # Convert row data to a hash for the ResultMetadata constructor
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

      # Create and return the ResultMetadata object
      ResultMetadata.new(**metadata_hash)
    end
  end
end
