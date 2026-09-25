# frozen_string_literal: true

require "fileutils"

module Awfy
  module OutputWriter
    module_function

    def write(text, output: nil)
      text = "#{text}\n" unless text.end_with?("\n")
      if output
        FileUtils.mkdir_p(File.dirname(output))
        File.write(output, text)
      else
        $stdout.write(text)
      end
    end
  end
end
