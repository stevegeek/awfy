# frozen_string_literal: true

module Awfy
  # One test measured by `awfy run`: result_data holds "isolation", "outcome", "collectors",
  # "meta" and, when the test recorded any, "checks".
  class MeasureResult < Result
  end
end
