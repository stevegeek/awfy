# frozen_string_literal: true

module Awfy
  # Runs one test through its passes: pass 0 is the untimed warm-up, pass 1 runs
  # every light collector, and each heavy collector gets a pass of its own. The isolation
  # wrapper and before_each/after_each run around every call, warm-up included. Measured
  # calls start after 3x GC.start.
  class PassRunner < Literal::Object
    GC_RUNS_BEFORE_MEASURE = 3
    ACTIVE_RUN_KEY = :awfy_active_pass_runner

    prop :collectors, _Array(Class), reader: :private
    prop :label, String, reader: :private
    prop :artefacts_dir, String, reader: :private

    class << self
      # The PassRunner currently executing a #measure call on this thread, or nil outside one.
      # Lets a suite helper like perform_job check the run's configured collectors (Bug 1 fix:
      # collector_key? below) without new plumbing through every call site down to the test
      # block, and without depending on any one pass's collector instances — the warm-up pass
      # (pass 0) always runs with none, by design, regardless of what the run is configured with.
      def current = Thread.current[ACTIVE_RUN_KEY]
    end

    def after_initialize
      @setups_done = {}.compare_by_identity
      @warned = {}
    end

    # True if a collector with this .key is configured for this run, independent of which pass
    # (if any) currently has it instantiated.
    def collector_key?(key) = collectors.any? { it.key == key }

    # Warns once per run (a fresh PassRunner starts unwarned), not once per process: a later,
    # separately run misconfigured suite still gets its own warning instead of being silently
    # masked by an earlier run's.
    def warn_once(warning_key, message)
      return if @warned[warning_key]
      @warned[warning_key] = true
      warn message
    end

    def measure(group, report, test)
      previous_run = Thread.current[ACTIVE_RUN_KEY]
      Thread.current[ACTIVE_RUN_KEY] = self
      run_setups(group, report)
      isolation, strategy = Isolation.resolve(report.hooks.isolate || group.hooks.isolate)
      hooks = {
        before_each: report.hooks.before_each || group.hooks.before_each,
        after_each: report.hooks.after_each || group.hooks.after_each
      }
      context = ->(pass) {
        CollectorContext.new(group_name: group.name, report_name: report.name, test_name: test.name,
          label:, pass:, artefacts_dir:)
      }

      call(test, strategy, hooks, [], context.call(0))
      light, heavy = collectors.partition { !it.heavy? }
      collected, outcome = call(test, strategy, hooks, light.map(&:new), context.call(1))
      heavy.each.with_index(2) do |klass, pass|
        collected = collected.merge(call(test, strategy, hooks, [klass.new], context.call(pass)).first)
      end

      Measurement.new(group_name: group.name, report_name: report.name, test_name: test.name,
        isolation: isolation.to_s, outcome:, collectors: collected)
    ensure
      Thread.current[ACTIVE_RUN_KEY] = previous_run
    end

    private

    # Group setup, then report setup, each once per runner, outside isolation. A hook
    # is marked done only once its setup.call has returned: a raising setup is retried, and
    # so keeps failing, for every later test of the group rather than being silently skipped.
    def run_setups(group, report)
      [group.hooks, report.hooks].each do |hooks|
        next if hooks.setup.nil? || @setups_done[hooks]
        hooks.setup.call
        @setups_done[hooks] = true
      end
    end

    def call(test, strategy, hooks, instances, context)
      strategy.wrap do
        hooks[:before_each]&.call
        begin
          measured(test, instances, context)
        ensure
          hooks[:after_each]&.call
        end
      end
    end

    def measured(test, instances, context)
      Outcome.reset!
      GC_RUNS_BEFORE_MEASURE.times { ::GC.start } if context.pass.positive?
      started = []
      value = begin
        with_arounds(instances, context) do
          instances.sort_by { -it.class.order }.each do |collector|
            collector.start(context)
            started << collector
          end
          test.block.call
        end
      rescue => error
        stop_after_error(started, context)
        raise error
      end
      collected = stop_all(instances, context)
      [collected, Outcome.resolve(value, collected)]
    end

    # Every collector must get its #stop call, ascending .order, even if an earlier one raises:
    # a broken collector must not swallow the others' results. All errors are collected;
    # the first is raised once every collector has been given the chance to stop.
    def stop_all(instances, context)
      collected = {}
      errors = []
      instances.sort_by { it.class.order }.each do |collector|
        collected[collector.class.key] = Collectors.normalize(collector.stop(context))
      rescue => error
        errors << error
      end
      raise errors.first if errors.any?
      collected
    end

    def with_arounds(instances, context, &block)
      instances.reverse.reduce(block) { |inner, collector| -> { collector.around(context) { inner.call } } }.call
    end

    # Unsubscribe whatever started, lowest .order first, the reverse of the descending
    # start order in `started`. The test's own error is the one that propagates.
    def stop_after_error(started, context)
      started.reverse_each do |collector|
        collector.stop(context)
      rescue => stop_error
        warn "awfy: #{collector.class.key} could not stop after a test error: #{stop_error.class}: #{stop_error.message}"
      end
    end
  end
end
