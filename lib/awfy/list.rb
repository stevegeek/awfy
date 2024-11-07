# frozen_string_literal: true

module Awfy
  class List < Command
    def list(group)
      say "> \"#{group[:name]}\":"
      group[:reports].each do |report|
        say "    \"#{report[:name]}\""
        report[:tests].each do |test|
          say "      | #{test[:control] ? "Control" : "Test"}: \"#{test[:name]}\""
        end
      end
    end
  end
end
