# frozen_string_literal: true

module Awfy
  module Rails
    # isolate :transaction. Pins each writing pool's connection with a
    # non-joinable transaction, as Rails transactional tests do (ConnectionPool#pin_connection!
    # runs begin_transaction(joinable: false, _lazy: false)), and rolls it back afterwards.
    # Pinning keeps the connection through the executor's clear_active_connections! at the end
    # of a request. after_commit callbacks still fire: inner transactions complete against a
    # non-joinable parent. IdentityCache also ignores non-joinable transactions, so cached
    # fetches behave as in production.
    #
    # Deliberately simpler than ActiveRecord::TestFixtures: that also subscribes to
    # "!connection.active_record" so pools that connect after setup still get pinned, and
    # calls setup_shared_connection_pool so reading-role connections share the writing
    # pool's transaction. A single-DB host app never establishes a pool after boot and has
    # no separate reading role, so it is unaffected; a multi-DB app with a replica would
    # need that extra wiring, which this module does not attempt.
    module TransactionIsolation
      module_function

      def available?
        defined?(::ActiveRecord::Base) ? writing_pools.any? : false
      end

      def wrap
        pinned = []
        error = nil
        broken = []
        result = begin
          writing_pools.each do |pool|
            # Record before pinning: pin_connection! can raise after partially pinning the
            # connection (e.g. #verify! or begin_transaction failing), and that connection
            # still needs unpinning.
            pinned << pool
            pool.pin_connection!(true)
            pool.lease_connection
          end
          yield
        rescue => e
          error = e
          nil
        ensure
          pinned.each do |pool|
            broken << pool unless pool.unpin_connection!
          rescue => unpin_error
            warn "awfy: could not unpin a connection after #{error ? "an error" : "the measured call"}: " \
              "#{unpin_error.class}: #{unpin_error.message}"
          end
        end
        raise error if error
        unless broken.empty?
          raise Awfy::Errors::IsolationBrokenError,
            "The measured call committed or rolled back the isolation transaction; its writes may have persisted"
        end
        result
      end

      def writing_pools = ::ActiveRecord::Base.connection_handler.connection_pool_list(:writing)
    end
  end
end
