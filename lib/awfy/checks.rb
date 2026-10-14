# frozen_string_literal: true

module Awfy
  # Named pass/fail expectations about a test's result, stored at result_data["checks"].
  # Unlike a raise, every check is recorded, so one run reports all of them; `awfy run` lists
  # each failed check under "failures". A check may be recorded in the test block or in an
  # Outcome.record block (which runs after the collectors stop, still inside the isolation).
  # Outside `awfy run` (ips, profiling and memory jobs call test blocks directly) a check is ignored.
  #
  #   Awfy::Checks.record("every row imported", imported == rows.size, "#{imported} of #{rows.size}")
  module Checks
    KEY = :awfy_checks

    class << self
      def record(name, pass, detail = nil)
        return unless PassRunner.current

        (Thread.current[KEY] ||= []) << {"name" => name.to_s, "pass" => pass ? true : false, "detail" => detail&.to_s}
      end

      def reset!
        Thread.current[KEY] = nil
      end

      def recorded = Thread.current[KEY] || []
    end
  end
end
