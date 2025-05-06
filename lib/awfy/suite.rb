# frozen_string_literal: true

module Awfy
  class Suite
    def initialize
      @groups = {}
    end

    attr_reader :groups

    def group(name, &)
      @groups[name] ||= Suites::Group.new(name:, reports: [])
      @current_group = @groups[name]
      instance_eval(&)
    end

    def report(name, &)
      current_group! << Suites::Report.new(name:, tests: [])
      instance_eval(&)
    end

    def control(name, &block)
      current_report! << Suites::ControlTest.new(name:, block:)
    end

    def test(name, &block)
      current_report! << Suites::Test.new(name:, block:)
    end

    def tests?
      @groups.any? do |_, group|
        group.reports? do |report|
          report.tests?
        end
      end
    end

    private

    def current_group!
      @current_group.tap do |group|
        raise "Not in group" unless group
      end
    end

    def current_report!
      current_group!
      @current_group.reports.last.tap do |report|
        raise "Not in report" unless report
      end
    end
  end
end
