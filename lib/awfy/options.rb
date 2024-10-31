# frozen_string_literal: true

module Awfy
  Options = Data.define(:verbose, :summary, :summary_format, :temp_output_directory, :setup_file_path, :tests_path, :compare_with_branch, :assert, :runtime) do
    def yjit_only? = runtime == "yjit"

    def both_runtimes? = runtime == "both"

    def show_summary? = summary

    def verbose? = verbose

    def assert? = assert

    def humanized_runtime = runtime.upcase
  end
end
