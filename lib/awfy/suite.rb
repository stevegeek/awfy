# frozen_string_literal: true

module Awfy
  class Suite
    def initialize(initial_groups = [])
      @groups_store = {}
      initial_groups.each do |group|
        @groups_store[group.name] = group
      end
    end

    def groups
      @groups_store.values
    end

    def group(name, &)
      @groups_store[name] ||= Suites::Group.new(name:, reports: [])
      @current_group = @groups_store[name]
      instance_eval(&)
    end

    def report(name, &)
      current_group! << Suites::Report.new(name:, tests: [])
      instance_eval(&)
    end

    # TODO: check name is unique for runtime, report combo

    # A control is a benchmark that should not change between runs. It is checking something that is unaffected by
    # changes you are making.
    def control(name, &block)
      current_report! << Suites::ControlTest.new(name:, block:)
    end

    # A test is benchmarking the actual change of interest. It is checking something that should change between runs.
    def test(name, &block)
      current_report! << Suites::BaselineTest.new(name:, block:)
    end

    # An alternative is a test that is not the main test, but is still of interest. Eg it might be an alternative
    # implementation that you are working with at the same time as your main 'test'
    def alternative(name, &block)
      current_report! << Suites::Test.new(name:, block:)
    end

    # Assert that results match conditions
    def assert(**configuration)
      # NOP for now...
    end

    def groups?
      !@groups_store.empty?
    end

    def tests?
      @groups_store.any? do |_, group|
        group.reports? do |report|
          report.tests?
        end
      end
    end

    def filter(group_names)
      self.class.new(groups.select { |group| group_names.include?(group.name) })
    end

    def valid_group?(name)
      @groups_store.key?(name)
    end

    def find_group(name)
      raise Errors::GroupNotFoundError unless valid_group?(name)

      @groups_store[name]
    end

    def find_report(group, report_name)
      group = find_group(group)
      report = group.reports.find { |r| r.name == report_name }
      report || raise(Errors::ReportNotFoundError.new(group.name, report_name))
    end

    def find_test(group, report_name, test_name)
      report = find_report(group, report_name)
      test = report.tests.find { |t| t.name == test_name }
      test || raise(Errors::ReportNotFoundError.new(group.name, report_name, test_name))
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
