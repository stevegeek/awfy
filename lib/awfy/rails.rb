# frozen_string_literal: true

# Optional Rails layer: `require "awfy/rails"` registers the Rails collectors. It
# never loads Rails: every Rails, Active Record, Active Support and Sidekiq constant is used at
# call time only, so `awfy compare` can require this file in a process without Rails.
# Zeitwerk ignores this file and lib/awfy/rails/ (lib/awfy.rb).
require "awfy"

module Awfy
  module Rails
    module Collectors
    end
  end
end

require_relative "rails/sql_normalizer"
require_relative "rails/collectors/sql"
require_relative "rails/collectors/instantiation"
require_relative "rails/collectors/cache"
require_relative "rails/collectors/sidekiq"
require_relative "rails/transaction_isolation"
require_relative "rails/helpers"

module Awfy
  module Rails
    class << self
      attr_writer :app

      def app = @app || ::Rails.application

      # Boots the host app by requiring its config/environment.
      def boot!(root)
        require File.join(root, "config/environment")
        RunMeta.merge!(
          "rails_env" => ::Rails.env.to_s,
          "rails" => ::Rails.version,
          "jemalloc" => ENV.fetch("LD_PRELOAD", "").include?("jemalloc")
        )
        ::Rails.application
      end

      # Warden's login_as for the next request only (store: false: no session needed).
      # event: :fetch, not the default :authentication: this stands in for Warden loading
      # the user from an existing session on an ordinary request, not a fresh sign-in. A
      # host app's trackable concern (e.g. Devise) hangs its post-authentication side
      # effects, such as an extra `update_tracked_fields!` UPDATE, on :authentication;
      # :fetch skips them, keeping every measured request the same shape.
      def login_as(user)
        require "warden"
        require "warden/test/helpers"
        unless @warden_test_mode
          ::Warden.test_mode!
          @warden_test_mode = true
        end
        Object.new.extend(::Warden::Test::Helpers).login_as(user, scope: :user, store: false, event: :fetch)
      end
    end
  end
end

[
  Awfy::Rails::Collectors::Sql,
  Awfy::Rails::Collectors::Instantiation,
  Awfy::Rails::Collectors::Cache,
  Awfy::Rails::Collectors::Sidekiq
].each { Awfy::Collectors.register(it) }

Awfy::Isolation.register(:transaction, Awfy::Rails::TransactionIsolation)
Awfy::Suite.include(Awfy::Rails::Helpers)
