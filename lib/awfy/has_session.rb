# frozen_string_literal: true

module Awfy
  module HasSession
    def self.included(base)
      base.prop :session, Awfy::Session, reader: :private
    end

    def git_client = session.git_client

    def config = session.config

    def say(...) = session.say(...)

    def say_error(...) = session.say_error(...)

    def color_supported? = session.color_supported?

    def unicode_supported? = session.unicode_supported?

    def verbose?(level = VerbosityLevel::BASIC) = session.verbose?(level)
  end
end
