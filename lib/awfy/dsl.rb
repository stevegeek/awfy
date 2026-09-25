# frozen_string_literal: true

module Awfy
  # DSL methods for benchmark configuration
  module Dsl
    def group(name, &)
      suite.group(name, &)
    end

    def groups
      suite.groups
    end

    def suite
      @suite ||= Suite.new
    end

    # Evaluates the block against a fresh suite and returns it; the global suite is untouched.
    def isolated_suite
      previous = @suite
      @suite = Suite.new
      yield
      @suite
    ensure
      @suite = previous
    end
  end
end
