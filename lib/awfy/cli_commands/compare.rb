# frozen_string_literal: true

require "json"

module Awfy
  module CLICommands
    class Compare < Base
      check_unknown_options!
      default_command :start

      desc "start", "Compare the latest :measure results of two labels"
      method_option :store, type: :string, desc: "Store path (SQLite file, or JSON directory)"
      method_option :baseline, type: :string, required: true
      method_option :against, type: :string, required: true
      method_option :group, type: :string, desc: "Only these groups (comma-separated; default: all)"
      method_option :format, type: :string, enum: %w[json md table], default: "md"
      method_option :output, type: :string
      def start
        group_names = options[:group]&.split(",")&.map(&:strip)
        doc = Commands::Compare.new(session:, baseline: options[:baseline], against: options[:against], group_names:).run
        text = case options[:format]
        when "json" then JSON.pretty_generate(doc)
        when "md" then Views::CompareMarkdown.render(doc)
        else Views::CompareTable.render(doc)
        end
        OutputWriter.write(text, output: options[:output])
      rescue Errors::LabelNotFoundError => e
        shell.say_error_and_exit e.message
      end
    end
  end
end
