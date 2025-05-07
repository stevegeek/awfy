# frozen_string_literal: true

module Awfy
  module Jobs
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group, Suites::Group
      prop :benchmarker, Awfy::Benchmarker

      def call
        raise NoMethodError, "You must implement the call method in your job class"
      end
    end
  end
end
