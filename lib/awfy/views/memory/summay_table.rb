# frozen_string_literal: true

module Awfy
  module Views
    module Memory
      class SummaryTable < Table
        def order_description
          case config.summary_order
          when "asc"
            "Results displayed in ascending order (lowest memory first)"
          when "desc"
            "Results displayed in descending order (highest memory first)"
          else # Default to "leader"
            "Results displayed as a leaderboard (best to worst)"
          end
        end
      end
    end
  end
end
