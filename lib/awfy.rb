# frozen_string_literal: true

require_relative "awfy/version"
require_relative "awfy/cli"

module Awfy
  class << self
    def group(name, &)
      @groups ||= {}
      @groups[name] ||= {name:, reports: []}.freeze
      @current_group = @groups[name]
      instance_eval(&)
    end

    attr_reader :groups

    def report(name, &)
      @current_group[:reports] << {name:, tests: []}.freeze
      instance_eval(&)
    end

    def control(name, &block)
      @current_group[:reports].last[:tests] << {name:, block:, control: true}.freeze
    end

    def test(name, &block)
      @current_group[:reports].last[:tests] << {name:, block:}.freeze
    end
  end
end
