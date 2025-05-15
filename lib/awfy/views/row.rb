# frozen_string_literal: true

module Awfy
  module Views
    class Row < Literal::Data
      prop :identifier, String
      prop :highlight, _Boolean, default: false, predicate: :public
      prop :columns, Hash

      def to_h
        columns
      end
    end
  end
end
