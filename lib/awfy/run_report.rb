# frozen_string_literal: true

module Awfy
  class RunReport
    def initialize(group, report, shell, git_client, options)
      @group = group
      @report = report
      @shell = shell
      @git_client = git_client
      @options = options
    end

    def start(&)
    end
  end
end
