# frozen_string_literal: true

module Awfy
  module Commands
    class List < Base
      def call
        view = Views::ListView.new(session:)
        if session.config.list
          view.display_group(@group)
        else
          view.display_table(@group)
        end
      end
    end
  end
end
