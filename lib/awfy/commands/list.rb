# frozen_string_literal: true

module Awfy
  module Commands
    class List < Base
      def list
        view = Views::ListView.new(session:)
        if session.config.table_format
          view.display_table(@group)
        else
          view.display_group(@group)
        end
      end
    end
  end
end
