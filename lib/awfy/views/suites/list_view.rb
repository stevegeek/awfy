# frozen_string_literal: true

module Awfy
  module Views
    module Suites
      class ListView < BaseView
        prop :group_name, String, reader: :private

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
              rows << Row.new(
                identifier: "#{test.name}/#{report.name}/#{group.name}",
                columns: {
                  group: group.name,
                  report: report.name,
                  test: test.name,
                  type: test.control? ? "Control" : "Test"
                }
              )
            end
          end

          title = "Tests in group: #{group.name}"

          table = ListTable.new(
            session:,
            group_name:,
            custom_title: title,
            rows: rows
          )

          say_table(table, {theme: :ansi, color: false})
        end
      end
    end
  end
end
