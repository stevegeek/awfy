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

    def report(name, &)
      suite.report(name, &)
    end

    def control(name, &)
      suite.control(name, &)
    end

    def test(name, &)
      suite.test(name, &)
    end

    def alternative(name, &)
      suite.alternative(name, &)
    end

    def suite
      @suite ||= Suite.new
    end
  end
end
