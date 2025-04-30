# frozen_string_literal: true

module Awfy
  module Commands
    class List < Base
      def list(group)
        # Create the list view directly
        view = Views::ListView.new(@shell, @options)

        # Display the list using the view based on options
        if @options&.table_format
          view.display_table(group)
        else
          view.display_group(group)
        end
      end
    end
  end
end
