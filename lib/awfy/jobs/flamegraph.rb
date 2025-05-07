# frozen_string_literal: true

require "vernier"

module Awfy
  module Jobs
    class Flamegraph < Base
      def generate(group, report_name, test_name)
        execute_report(group, report_name) do |report, runtime|
          execute_tests(report, test_name) do |test, iterations|
            "report-#{group[:name]}-#{report[:name]}-#{test[:name]}".gsub(/[^A-Za-z0-9_\-]/, "_")
            save_to(:flamegraph, group, report, runtime) do |file_name|
              generate_flamegraph(file_name) do
                i = 0
                while i < iterations
                  test[:block].call
                  i += 1
                end
              end
            end
          end
        end
      end

      private

      def generate_flamegraph(filename = nil, open: true, ignore_gc: false, interval: 1000, &)
        result = Vernier.profile(out: filename, gc: !ignore_gc, interval: interval, &)
        `bundle exec profile-viewer #{filename}` if open
        result
      end
    end
  end
end
