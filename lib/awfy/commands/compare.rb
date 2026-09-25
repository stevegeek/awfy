# frozen_string_literal: true

module Awfy
  module Commands
    class Compare < Literal::Object
      include Awfy::HasSession

      prop :baseline, String, reader: :private
      prop :against, String, reader: :private
      prop :group_names, _Nilable(_Array(String)), reader: :private

      def run
        require "awfy/rails" # Rails collectors' compare/extras; loads no Rails
        Comparison.new(store: session.results_store, baseline:, against:, group_names:).call
      end
    end
  end
end
