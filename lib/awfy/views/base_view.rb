# frozen_string_literal: true

require "rainbow"

module Awfy
  module Views
    # Base class for all views that handle output formatting
    class BaseView < Literal::Object
      include HasSession
      include TableFormatter
      include ComparisonFormatters
    end
  end
end
