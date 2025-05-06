# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group, Suites::Group
      prop :benchmarker, Awfy::Benchmarker
    end
  end
end
