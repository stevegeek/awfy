# frozen_string_literal: true

module Awfy
  module Errors
    # Raised before anything is stashed or checked out, when doing so could lose work or
    # leave no ref to return to.
    class UnsafeCheckoutError < GitStateError
    end
  end
end
