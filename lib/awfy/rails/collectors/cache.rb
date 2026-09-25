# frozen_string_literal: true

module Awfy
  module Rails
    module Collectors
      # Counts ActiveSupport::Cache reads, hits, misses and writes. It also counts compare-and-set
      # calls ("cas") and IdentityCache's own events ("identity_cache_*"); those keys appear only
      # when such events occur, so an app without IdentityCache gets the four base counts.
      #
      # The identity_cache_* counts are IdentityCache's logical view (a fetch and how its keys were
      # served: memoized, from the cache backend, or resolved from the database). The store calls
      # IdentityCache makes to serve them (cas, add as a write, read) are also in the base counts,
      # so do not add the two views together.
      class Cache < Awfy::Collector
        EVENTS = /\A(?:cache_(?:read|read_multi|write|write_multi|cas|cas_multi)\.active_support|(?:cache_fetch|cache_fetch_multi|cache_write|cache_delete|cache_delete_multi|hydration)\.identity_cache)\z/

        def self.key = "cache"

        def start(_context)
          @counts = {"reads" => 0, "hits" => 0, "misses" => 0, "writes" => 0}
          @subscriber = ::ActiveSupport::Notifications.subscribe(EVENTS) { |event| record(event) }
        end

        def stop(_context)
          ::ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
          @subscriber = nil
          if @counts.key?("identity_cache_resolve_miss_ms")
            @counts["identity_cache_resolve_miss_ms"] = @counts["identity_cache_resolve_miss_ms"].round(3)
          end
          @counts
        end

        private

        def record(event)
          payload = event.payload
          case event.name
          when "cache_read.active_support"
            count_reads(1, payload[:hit] ? 1 : 0)
          when "cache_read_multi.active_support"
            count_reads(Array(payload[:key]).size, Array(payload[:hits]).size)
          when "cache_write.active_support"
            @counts["writes"] += 1
          when "cache_write_multi.active_support"
            @counts["writes"] += payload[:key].respond_to?(:size) ? payload[:key].size : 1
          when "cache_cas.active_support", "cache_cas_multi.active_support"
            add("cas", Array(payload[:key]).size)
          when "cache_fetch.identity_cache", "cache_fetch_multi.identity_cache"
            count_identity_cache_fetch(payload)
          when "cache_write.identity_cache"
            add("identity_cache_writes", 1)
          when "cache_delete.identity_cache", "cache_delete_multi.identity_cache"
            add("identity_cache_deletes", 1)
          when "hydration.identity_cache"
            add("identity_cache_hydrations", 1)
          end
        end

        def count_reads(reads, hits)
          @counts["reads"] += reads
          @counts["hits"] += hits
          @counts["misses"] += reads - hits
        end

        # IdentityCache sets memo_hits, cache_hits and cache_misses per fetch; together they are
        # the number of keys asked for. resolve_miss_time is in seconds.
        def count_identity_cache_fetch(payload)
          memo_hits = payload[:memo_hits].to_i
          cache_hits = payload[:cache_hits].to_i
          cache_misses = payload[:cache_misses].to_i
          add("identity_cache_fetches", 1)
          add("identity_cache_keys", memo_hits + cache_hits + cache_misses)
          add("identity_cache_memo_hits", memo_hits)
          add("identity_cache_hits", cache_hits)
          add("identity_cache_misses", cache_misses)
          add("identity_cache_resolve_miss_ms", payload[:resolve_miss_time].to_f * 1000)
        end

        def add(name, amount)
          @counts[name] = @counts.fetch(name, 0) + amount
        end
      end
    end
  end
end
