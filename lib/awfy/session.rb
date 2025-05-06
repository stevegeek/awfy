# frozen_string_literal: true

module Awfy
  class Session < Literal::Data
    prop :shell, _Interface(:ask, :say, :say_error, :say_status, :mute, :mute?), default: -> { Thor::Shell::Basic.new }
    prop :config, Awfy::Config
    prop :git_client, Awfy::GitClient, default: -> { Awfy::GitClient.new(Dir.pwd) }

    def say(...) = shell.say(...)

    def say_error(...) = shell.say_error(...)

    def verbose? = config.verbose?
  end
end
