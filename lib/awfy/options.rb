# frozen_string_literal: true

module Awfy
  class Options
    def initialize(verbose:, summary:, summary_format:, temp_output_directory:, setup_file_path:, tests_path:, compare_with_branch:, assert:, runtime:)
      @verbose = verbose
      @summary = summary
      @summary_format = summary_format
      @temp_output_directory = temp_output_directory
      @setup_file_path = setup_file_path
      @tests_path = tests_path
      @compare_with_branch = compare_with_branch
      @assert = assert
      @runtime = runtime
    end

    def yjit_only? = runtime == "yjit"

    def both_runtimes? = runtime == "both"

    def show_summary? = @summary

    def verbose? = @verbose

    def assert? = @assert

    def humanized_runtime = @runtime.upcase

    attr_reader :temp_output_directory, :setup_file_path, :tests_path, :compare_with_branch, :runtime, :summary_format
  end
end
