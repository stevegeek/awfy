# frozen_string_literal: true

module Awfy
  class List
    def self.perform(group, shell)
      new(group, shell).perform
    end

    def initialize(group, shell)
      @group = group
      @shell = shell
    end

    def perform
      say "> #{@group[:name]}"
      @group[:reports].each do |report|
        say "  - #{report[:name]}"
        report[:tests].each do |test|
          say "    Test: #{test[:name]}"
        end
      end
    end

    def say(message) = @shell.say message
  end
end
