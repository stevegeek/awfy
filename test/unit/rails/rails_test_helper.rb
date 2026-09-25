# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "active_record"
require "active_support/cache"
require "awfy/rails"

# One SQLite file per test process (each connection would get its own :memory: database).
module RailsTestHelper
  def self.connect!
    return if @connected

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(Dir.mktmpdir("awfy-rails"), "test.sqlite3"))
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define { create_table(:awfy_widgets, force: true) { |t| t.string :name } }
    @connected = true
  end

  def context(pass = 1)
    Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass:, artefacts_dir: Dir.tmpdir)
  end

  def collect(collector)
    collector.start(context)
    yield
    collector.stop(context)
  end
end

class AwfyWidget < ActiveRecord::Base
  class << self
    attr_accessor :committed
  end
  self.committed = []
  after_commit { self.class.committed << id }
end
