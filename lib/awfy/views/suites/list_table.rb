# frozen_string_literal: true

module Awfy
  module Views
    module Suites
      class ListTable < Table
        prop :custom_title, String, reader: :private

        def title
          custom_title
        end

        def order_description
        end
      end
    end
  end
end
