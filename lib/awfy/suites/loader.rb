# frozen_string_literal: true

module Awfy
  module Suites
    class Loader < Literal::Object
      include HasSession

      prop :group_names, _Nilable(_Array(String))
      prop :suite_path, _Nilable(String)

      def load
        @suite ||= load_suite
        apply_filter(@suite)
      end

      private

      def load_suite
        require File.expand_path(config.setup_file_path, Dir.pwd)
        return load_suite_file if @suite_path

        expanded_tests_path = File.expand_path(config.tests_path, Dir.pwd)
        Dir.glob(File.join(expanded_tests_path, "*.rb")).each { |file| require file }
        ::Awfy.suite
      end

      # `awfy run <suite-path>`: Kernel.load into a fresh suite, so only this file's groups run,
      # also when the same process loads it twice (the integration tests do).
      def load_suite_file
        path = File.expand_path(@suite_path, Dir.pwd)
        raise Errors::SuiteError, "Suite file '#{path}' not found" unless File.file?(path)
        ::Awfy.isolated_suite { Kernel.load(path) }
      end

      def apply_filter(suite_all)
        return suite_all if @group_names.nil? || @group_names.empty?
        @group_names.each do |group_name|
          raise Errors::GroupNotFoundError.new(group_name) unless suite_all.valid_group?(group_name)
        end
        suite_all.filter(@group_names)
      end
    end
  end
end
