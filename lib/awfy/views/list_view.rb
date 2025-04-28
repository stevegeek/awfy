# frozen_string_literal: true

module Awfy
  module Views
    # View class for displaying test list output
    class ListView < BaseView
      # Format and display a list of tests in a group
      # @param group [Hash] The group to display
      # @return [void]
      def display_group(group)
        say "> \"#{group[:name]}\":"
        group[:reports].each do |report|
          display_report(report)
        end
      end
      
      # Format and display a report and its tests
      # @param report [Hash] The report to display
      # @return [void]
      def display_report(report)
        say "    \"#{report[:name]}\""
        report[:tests].each do |test|
          display_test(test)
        end
      end
      
      # Format and display a test
      # @param test [Hash] The test to display
      # @return [void]
      def display_test(test)
        say "      | #{test[:control] ? "Control" : "Test"}: \"#{test[:name]}\""
      end
      
      # Format and display a list of all tests in a table format
      # @param group [Hash] The group to display
      # @return [void]
      def display_table(group)
        rows = []
        
        group[:reports].each do |report|
          report[:tests].each do |test|
            rows << [
              group[:name],
              report[:name],
              test[:name],
              test[:control] ? "Control" : "Test"
            ]
          end
        end
        
        title = "Tests in group: #{group[:name]}"
        headings = ["Group", "Report", "Test", "Type"]
        
        table = format_table(title, headings, rows)
        say table
      end
    end
  end
end