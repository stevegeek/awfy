# frozen_string_literal: true

module Awfy
  module Jobs
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group, Suites::Group, reader: :private
      prop :benchmarker, Awfy::Benchmarker, reader: :private

      def call
        raise NoMethodError, "You must implement the call method in your job class"
      end
    end
  end
end
