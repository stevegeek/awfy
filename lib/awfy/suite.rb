# frozen_string_literal: true

module Awfy
  class Suite
    def initialize
      @groups = {}
    end

    attr_reader :groups

    def group(name, &)
      @groups[name] ||= {name:, reports: []}.freeze
      @current_group = @groups[name]
      instance_eval(&)
    end

    def report(name, &)
      current_group![:reports] << {name:, tests: []}.freeze
      instance_eval(&)
    end

    def control(name, &block)
      current_report![:tests] << {name:, block:, control: true}.freeze
    end

    def test(name, &block)
      current_report![:tests] << {name:, block:}.freeze
    end

    private

    def current_group!
      @current_group.tap do |group|
        raise "Not in group" unless group
      end
    end

    def current_report!
      current_group!
      @current_group[:reports].last.tap do |report|
        raise "Not in report" unless report
      end
    end
  end
end
