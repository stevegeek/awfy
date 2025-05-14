# frozen_string_literal: true

module Awfy
  module Commands
    class Store < Base
      def clean
        policy = RetentionPolicies.create(config.retention_policy)
        results_store = Stores.create(config.storage_backend, config.storage_name, policy)
        results_store.clean_results
        session.say "Cleaned benchmark results of #{config.storage_backend} in '#{config.storage_name}', using '#{policy.name}' retention policy"
      end
    end
  end
end
