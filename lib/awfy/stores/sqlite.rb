# frozen_string_literal: true

require "fileutils"
require "json"
require "sqlite3"

module Awfy
  module Stores
    class Sqlite < Base
      CREATE_RESULTS_TABLE_SCHEMA = <<~SQL
        CREATE TABLE IF NOT EXISTS results (
          id INTEGER PRIMARY KEY,
          result_id TEXT UNIQUE,
          control BOOLEAN DEFAULT 0,
          baseline BOOLEAN DEFAULT 0,
          type TEXT,
          group_name TEXT,
          report_name TEXT,
          runtime TEXT,
          timestamp INTEGER,
          branch TEXT,
          commit_hash TEXT,
          commit_message TEXT,
          ruby_version TEXT,
          result_data TEXT
        );
      SQL

      def after_initialize
        setup_database
      end

      def save_result(result)
        with_database_connection do |db|
          store_benchmark_result(db, result)
        end

        result.result_id
      end

      def query_results(type: nil, group: nil, report: nil, runtime: nil, commit: nil)
        results = []

        with_database_connection do |db|
          db.results_as_hash = true

          sql, params = build_query_sql(type, group, report, runtime, commit)
          db.execute(sql, params) do |row|
            results << create_result_from_row(row)
          end
        end

        results
      end

      def load_result(result_id)
        result = nil

        with_database_connection do |db|
          db.results_as_hash = true

          sql = "SELECT * FROM results WHERE result_id = ?"
          db.execute(sql, [result_id]) do |row|
            result = create_result_from_row(row)
          end
        end

        result
      end

      def clean_results
        with_database_connection do |db|
          query_all_results.each do |result|
            unless retained_by_retention_policy?(result)
              db.execute("DELETE FROM results WHERE result_id = ?", [result.result_id])
            end
          end
        end
      end

      private

      def query_all_results
        results = []

        with_database_connection do |db|
          db.results_as_hash = true
          sql = "SELECT * FROM results"
          db.execute(sql) do |row|
            results << create_result_from_row(row)
          end
        end

        results
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
        db = SQLite3::Database.new("#{storage_name}.db")
        db.busy_timeout = 5000 # 5 seconds timeout for busy database
        db
      end

      def setup_database
        with_database_connection do |db|
          db.execute(CREATE_RESULTS_TABLE_SCHEMA)
          create_indexes(db)
        end
      end

      def create_indexes(db)
        db.execute "CREATE INDEX IF NOT EXISTS idx_results_type ON results (type);"
        db.execute "CREATE INDEX IF NOT EXISTS idx_results_group ON results (group_name);"
        db.execute "CREATE INDEX IF NOT EXISTS idx_results_report ON results (report_name);"
        db.execute "CREATE INDEX IF NOT EXISTS idx_results_commit ON results (commit_hash);"
        db.execute "CREATE INDEX IF NOT EXISTS idx_results_timestamp ON results (timestamp);"
      end

      def store_benchmark_result(db, result)
        timestamp = result.timestamp.to_i
        result_data_json = result.result_data.to_json

        db.execute(
          "INSERT INTO results (result_id, type, control, baseline, group_name, report_name, runtime,
            timestamp, branch, commit_hash, commit_message, ruby_version, result_data)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [
            result.result_id,
            result.type.to_s,
            result.control? ? 1 : 0,
            result.baseline? ? 1 : 0,
            result.group_name,
            result.report_name,
            result.runtime.value,
            timestamp,
            result.branch,
            result.commit,
            result.commit_message,
            result.ruby_version,
            result_data_json
          ]
        )
      end

      def build_query_sql(type, group, report, runtime, commit)
        sql = "SELECT * FROM results WHERE 1=1"
        params = []

        if type
          sql += " AND type = ?"
          params << type.to_s
        end

        if group
          sql += " AND group_name = ?"
          params << group
        end

        if report
          sql += " AND report_name = ?"
          params << report
        end

        if commit
          sql += " AND commit_hash = ?"
          params << commit
        end

        if runtime.is_a?(String)
          sql += " AND runtime = ?"
          params << runtime
        elsif runtime.is_a?(Awfy::Runtimes)
          sql += " AND runtime = ?"
          params << runtime.value
        end

        # Order by timestamp descending (newest first)
        sql += " ORDER BY timestamp DESC"

        [sql, params]
      end

      def create_result_from_row(row)
        result_data = JSON.parse(row["result_data"]) if row["result_data"]
        Result.deserialize(
          **row.transform_keys(&:to_sym),
          result_data: result_data
        )
      end
    end
  end
end
