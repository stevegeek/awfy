# frozen_string_literal: true

module Awfy
  module Errors
    # Raised when awfy could not check out the original ref again, or could not re-apply the
    # changes it stashed. The message says what is left for the user to restore by hand.
    class CheckoutRestoreError < GitStateError
    end
  end
end
