# frozen_string_literal: true

module Awfy
  class Profiling < Command
    def generate(group, report, test)
      if verbose?
        say "> Profiling for:"
        say "> #{group[:name]} (iterations: #{options[:iterations]})...", :cyan
      end
      execute_report(group, report_name) do |report, runtime|
        execute_tests(report, test_name) do |test, iterations|
          data = StackProf.run(mode: :cpu, interval: 100) do
            i = 0
            while i < iterations
              test[:block].call
              i += 1
            end
          end
          StackProf::Report.new(data).print_text
        end
      end
    end
  end
end
