# frozen_string_literal: true

module Awfy
  class Session < Literal::Data
    prop :shell, Awfy::Shell
    prop :config, Awfy::Config
    prop :git_client, Awfy::GitClient, default: -> { Awfy::GitClient.new(Dir.pwd) }
    prop :results_store, Awfy::Stores::Base

    def say(...) = shell.say(...)

    def say_error(...) = shell.say_error(...)

    def color_supported? = shell.color_supported?

    def unicode_supported? = shell.unicode_supported?

    def verbose?(level = VerbosityLevel::BASIC) = config.verbose?(level)

    def say_configuration
      config_view = Views::ConfigView.new(session: self)
      config_view.display_configuration
    end
  end
end
