# frozen_string_literal: true

module Awfy
  class GitClient
    def initialize(path)
      @client = Git.open(path)
    end
  end
end
