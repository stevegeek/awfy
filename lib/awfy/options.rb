# frozen_string_literal: true

module Awfy
  class Options
    def initialize(verbose:, temp_output_directory:, setup_file_path:, tests_path:, compare_with_branch:, assert:, runtime:)
      @verbose = verbose
      @temp_output_directory = temp_output_directory
      @setup_file_path = setup_file_path
      @tests_path = tests_path
      @compare_with_branch = compare_with_branch
      @assert = assert
      @runtime = runtime
    end

    def verbose?
      @verbose
    end

    def assert?
      @assert
    end

    def humanized_runtime
      @runtime.upcase
    end

    attr_reader :temp_output_directory, :setup_file_path, :tests_path, :compare_with_branch, :runtime
  end
end
