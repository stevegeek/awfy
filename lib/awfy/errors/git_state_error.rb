# frozen_string_literal: true

module Awfy
  module Errors
    # The working tree is not in a state where awfy can check out other refs and come back.
    class GitStateError < StandardError
    end
  end
end
