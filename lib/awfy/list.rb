# frozen_string_literal: true

module Awfy
  class List < Command
    def list(group)
      # Create a view for the list output
      view = Views::ViewFactory.create(:list, @shell, @options)
      
      # Display the list using the view based on options
      if @options&.table_format
        view.display_table(group)
      else
        view.display_group(group)
      end
    end
  end
end
