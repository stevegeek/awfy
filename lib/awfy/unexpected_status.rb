# frozen_string_literal: true

module Awfy
  # Raised by the request helper when the status is outside `expect:`.
  class UnexpectedStatus < StandardError
  end
end
