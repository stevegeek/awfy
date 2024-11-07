# frozen_string_literal: true

module Awfy
  class Flamegraph < Command
    def generate(group, report, test)
      execute_report(group, report_name) do |report, runtime|
        execute_tests(report, test_name) do |test, _|
          label = "report-#{group[:name]}-#{report[:name]}-#{test[:name]}".gsub(/[^A-Za-z0-9_\-]/, "_")
          generate_flamegraph(label) do
            test[:block].call
          end
        end
      end
    end

    private

    def generate_flamegraph(label = nil, open: true, ignore_gc: false, interval: 1000, &)
      fg = Singed::Flamegraph.new(label: label, ignore_gc: ignore_gc, interval: interval)
      result = fg.record(&)
      fg.save
      fg.open if open
      result
    end
  end
end
