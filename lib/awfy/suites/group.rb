# frozen_string_literal: true

module Awfy
  module Suites
    class Group < Literal::Data
      prop :name, String
      prop :reports, _Array(Report)
      prop :hooks, Suites::Hooks, default: -> { Suites::Hooks.new }
      prop :assertions, _Array(Suites::Assertion), default: -> { [] }

      def <<(report)
        @reports << report
      end

      def reports?
        @reports.any?
      end

      def tests?
        @reports.any?(&:tests?)
      end

      def size
        @reports.map(&:size).sum
      end
    end
  end
end
