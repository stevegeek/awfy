# frozen_string_literal: true

module Awfy
  module Suites
    class Loader < Literal::Object
      include HasSession

      prop :group_names, _Nilable(_Array(String))

      def load
        return apply_filter if @loaded

        expanded_setup_file_path = File.expand_path(config.setup_file_path, Dir.pwd)
        expanded_tests_path = File.expand_path(config.tests_path, Dir.pwd)
        test_files = Dir.glob(File.join(expanded_tests_path, "*.rb"))

        require expanded_setup_file_path
        test_files.each { |file| require file }

        @loaded = true

        apply_filter
      end

      private

      def apply_filter
        suite_all = ::Awfy.suite
        return suite_all if @group_names.nil? || @group_names.empty?
        @group_names&.each do |group_name|
          raise Errors::GroupNotFoundError.new(group_name) unless suite_all.valid_group?(group_name)
        end
        suite_all.filter(@group_names)
      end
    end
  end
end
