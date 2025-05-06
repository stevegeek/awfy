# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group, Suites::Group
      prop :benchmarker, Awfy::Benchmarker

      def call
        raise NoMethodError, "You must implement the call method in your command class"
      end
    end
  end
end
