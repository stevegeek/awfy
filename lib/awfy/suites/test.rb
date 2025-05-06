# frozen_string_literal: true

module Awfy
  module Suites
    class Test < Literal::Data
      prop :name, String
      prop :block, Proc

      def control? = false
    end
  end
end
