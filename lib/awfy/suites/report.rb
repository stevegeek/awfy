# frozen_string_literal: true

module Awfy
  module Suites
    class Report < Literal::Data
      prop :name, String
      prop :tests, _Array(Test)

      def <<(test)
        @tests << test
      end

      def tests?
        @tests.any?
      end

      def size
        @tests.size
      end
    end
  end
end
