# frozen_string_literal: true

require "json"

module Awfy
  module CLICommands
    # `awfy run` (mapped to this subcommand: "run" is a Thor reserved word).
    class Measure < Base
      check_unknown_options!
      default_command :start

      desc "start SUITE_PATH", "Measure every test of one suite file with collectors; store one :measure result per test"
      method_option :label, type: :string, desc: "Run label (default: git branch, else 'unlabelled')"
      method_option :store, type: :string, desc: "Store path (SQLite file, or JSON directory)"
      method_option :collectors, type: :string, default: "timing,gc,rss", desc: "Comma-separated collector keys"
      method_option :vernier, type: :boolean, default: false, desc: "Add the vernier collector (own pass)"
      method_option :group, type: :string, desc: "Only this group"
      method_option :report, type: :string, desc: "Only this report"
      method_option :artefacts, type: :string, desc: "Directory for collector artefacts"
      method_option :format, type: :string, enum: %w[json table], default: "table"
      method_option :output, type: :string, desc: "Write the output to this file instead of stdout"
      def start(suite_path)
        keys = options[:collectors].split(",").map(&:strip).reject(&:empty?)
        keys << "vernier" if options[:vernier]
        doc = Commands::Run.new(
          session:, suite_path:, label: options[:label], collector_keys: keys, artefacts_dir: options[:artefacts],
          group_names: options[:group] ? [options[:group]] : nil, report_name: options[:report]
        ).run
        text = (options[:format] == "json") ? JSON.pretty_generate(doc) : Views::MeasureTable.render(doc)
        OutputWriter.write(text, output: options[:output])
        shell.say_error_and_exit "#{doc["failures"].size} test(s) failed" unless doc["failures"].empty?
      rescue Errors::SuiteError, Errors::UnknownCollectorError, Errors::IsolationUnavailableError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
