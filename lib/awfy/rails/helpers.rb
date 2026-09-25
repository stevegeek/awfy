# frozen_string_literal: true

module Awfy
  module Rails
    # Mixed into Awfy::Suite: test blocks are closures evaluated with the suite as self.
    module Helpers
      def perform_job(klass, *args, **kwargs)
        Awfy::Outcome.record { |collected| Awfy::Rails::Collectors::Sidekiq.outcome(collected["sidekiq"]) }
        warn_if_sidekiq_collector_not_configured
        klass.new.perform(*args, **kwargs)
      end

      def request(verb, path, host:, headers: {}, params: {}, as: nil, expect: 200..399)
        # action_dispatch/testing/integration eagerly defines IntegrationTest, which references
        # ActionController::TemplateAssertions; action_controller must be loaded first, even
        # outside a full Rails boot.
        require "action_controller"
        require "action_dispatch/testing/integration"
        session = ::ActionDispatch::Integration::Session.new(Awfy::Rails.app)
        session.host!(host)
        Awfy::Rails.login_as(as) if as
        session.process(verb.to_s.downcase.to_sym, path, params:, headers:)
        status = session.response.status
        unless expect === status
          raise Awfy::UnexpectedStatus, "#{verb.to_s.upcase} #{host}#{path} returned #{status}, expected #{expect}"
        end
        Awfy::Outcome.record({"status" => status, "body_bytes" => session.response.body.bytesize})
        session.response
      ensure
        # login_as queues a one-shot login for the next request to reach Warden's on_request
        # callback. If this request never reaches it (app isn't Warden-wrapped, or raises
        # first), the queued login would otherwise leak into a later, unrelated request.
        ::Warden.test_reset! if as
      end

      private

      # perform_job's outcome depends on this collector, but it does not know which pass (if
      # any) instantiated it: the warm-up pass always runs with no collector instances, by
      # design, regardless of what the run is configured with. Checking the run's configured
      # collector list (PassRunner#collector_key?), not any one pass's instances, is what a
      # correctly configured run actually needs checked, and avoids warning on that run's own
      # warm-up pass. Scoped to the run (PassRunner#warn_once), not the process, so a later,
      # separately run misconfigured suite still gets warned instead of being silently masked
      # by an earlier run's warning.
      def warn_if_sidekiq_collector_not_configured
        runner = Awfy::PassRunner.current
        return unless runner
        return if runner.collector_key?(Awfy::Rails::Collectors::Sidekiq.key)

        runner.warn_once(:sidekiq_inactive,
          "awfy: perform_job's outcome needs the sidekiq collector, which is not active for this run")
      end
    end
  end
end
