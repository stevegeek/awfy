# frozen_string_literal: true

module Awfy
  module Views
    class ListView < BaseView
      def display_group(group)
        say "> \"#{group.name}\":"
        group.reports.each do |report|
          display_report(report)
        end
      end

      def display_report(report)
        say "    \"#{report.name}\""
        report.tests.each do |test|
          display_test(test)
        end
      end

      def display_test(test)
        say "      | #{test.control? ? "Control" : "Test"}: \"#{test.name}\""
      end

      def display_table(group)
        rows = []

        group.reports.each do |report|
          report.tests.each do |test|
            rows << [
              group.name,
              report.name,
              test.name,
              test.control? ? "Control" : "Test"
            ]
          end
        end

        title = "Tests in group: #{group.name}"
        headings = %w[Group Report Test Type]

        table = say_table(title, headings, rows)
        say table
      end
    end
  end
end
