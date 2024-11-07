# frozen_string_literal: true

module Awfy
  Options = Data.define(:verbose, :quiet, :summary, :summary_order, :save, :temp_output_directory, :results_directory, :setup_file_path, :tests_path, :compare_with_branch, :compare_control, :assert, :runtime, :test_time, :test_iterations, :test_warm_up) do
    def yjit_only? = runtime == "yjit"

    def both_runtimes? = runtime == "both"

    def show_summary? = summary

    def quiet? = quiet

    def verbose? = verbose

    def assert? = assert

    def compare_control? = compare_control

    def humanized_runtime = runtime.upcase

    def save? = save
  end
end
