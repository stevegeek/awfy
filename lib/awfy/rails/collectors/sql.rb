# frozen_string_literal: true

module Awfy
  module Rails
    module Collectors
      # sql.active_record. Counts exclude SCHEMA, TRANSACTION and cached queries. Each counted
      # query is fingerprinted and attributed to its first app frame; a fingerprint reaching the
      # threshold from one frame is an N+1 candidate.
      class Sql < Awfy::Collector
        IGNORED_NAMES = %w[SCHEMA TRANSACTION].freeze
        DEFAULT_THRESHOLD = 5
        # This gem's own lib/ directory: a cleaned frame that still points in here (the
        # subscriber block below, when the host app's backtrace_cleaner has no silencers)
        # is never the app frame we want to attribute the query to.
        AWFY_LIB_DIR = File.expand_path("../../..", __dir__)

        class << self
          attr_writer :frame_finder

          def key = "sql"

          # Per-query caller + backtrace cleaning is comparatively heavy: give it its own
          # pass so it doesn't bias the light pass's timing/GC numbers.
          def heavy? = true

          def threshold = Integer(ENV.fetch("AWFY_N_PLUS_ONE_THRESHOLD", DEFAULT_THRESHOLD.to_s))

          # A callable taking a `caller` Array and returning the first app frame or nil.
          def frame_finder
            @frame_finder || method(:rails_frame)
          end

          def rails_frame(stack)
            return nil unless defined?(::Rails) && ::Rails.respond_to?(:backtrace_cleaner)

            ::Rails.backtrace_cleaner.clean(stack).find { |line| !line.start_with?(AWFY_LIB_DIR) }
          end

          def metrics(data) = data.slice("queries", "cached", "sql_ms")

          # Keyed on SQL + frame file without the line, so code that moved is not reported.
          def extras(base, other)
            base_keys = base.fetch("n_plus_one", []).map { candidate_key(it) }
            other_keys = other.fetch("n_plus_one", []).map { candidate_key(it) }
            {
              "n_plus_one_gone" => base.fetch("n_plus_one", []).reject { other_keys.include?(candidate_key(it)) },
              "n_plus_one_new" => other.fetch("n_plus_one", []).reject { base_keys.include?(candidate_key(it)) }
            }
          end

          def candidate_key(candidate) = [candidate["sql"], candidate["frame"].to_s.sub(/:\d+.*\z/, "")]
        end

        def start(_context)
          @queries = 0
          @cached = 0
          @ms = 0.0
          @by_sql = Hash.new { |hash, sql| hash[sql] = Hash.new(0) }
          @subscriber = ::ActiveSupport::Notifications.subscribe("sql.active_record") { |event| record(event) }
        end

        def stop(_context)
          ::ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
          @subscriber = nil
          threshold = self.class.threshold
          fingerprints = @by_sql.to_h do |sql, frames|
            [sql, {"count" => frames.values.sum, "frame" => frames.max_by { |_, count| count }&.first}]
          end
          n_plus_one = @by_sql.flat_map do |sql, frames|
            frames.filter_map { |frame, count| {"sql" => sql, "frame" => frame, "count" => count} if frame && count >= threshold }
          end
          {
            "queries" => @queries, "cached" => @cached, "sql_ms" => @ms.round(3),
            "fingerprints" => fingerprints, "n_plus_one" => n_plus_one.sort_by { -it["count"] }
          }
        end

        private

        def record(event)
          payload = event.payload
          return if IGNORED_NAMES.include?(payload[:name])
          if payload[:cached]
            @cached += 1
            return
          end

          @queries += 1
          @ms += event.duration
          @by_sql[SqlNormalizer.normalize(payload[:sql])][self.class.frame_finder.call(caller)] += 1
        end
      end
    end
  end
end
