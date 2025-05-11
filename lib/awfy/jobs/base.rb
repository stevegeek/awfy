# frozen_string_literal: true

module Awfy
  module Jobs
    class Base < Literal::Object
      include Awfy::HasSession

      prop :benchmarker, Awfy::Benchmarker, reader: :private
      prop :results_manager, Awfy::ResultsManager, reader: :private

      prop :group, Suites::Group, reader: :private

      prop :report_name, _Nilable(String), reader: :private
      prop :test_name, _Nilable(String), reader: :private

      def call
        raise NoMethodError, "You must implement the call method in your job class"
      end
    end
  end
end
