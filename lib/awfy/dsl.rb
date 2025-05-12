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
  end
end
