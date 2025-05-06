# frozen_string_literal: true

module Awfy
  module Suites
    class Loader < Literal::Object
      include HasSession

      def load
        expanded_setup_file_path = File.expand_path(config.setup_file_path, Dir.pwd)
        expanded_tests_path = File.expand_path(config.tests_path, Dir.pwd)
        test_files = Dir.glob(File.join(expanded_tests_path, "*.rb"))

        require expanded_setup_file_path
        test_files.each { |file| require file }

        ::Awfy.suite
      end
    end
  end
end
