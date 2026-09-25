# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# `awfy compare` requires awfy/rails in a process without Rails.
class RailsStandaloneLoadTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_requires_without_rails_and_registers_the_keys
    code = 'require "awfy/rails"; puts Awfy::Collectors.keys.join(","); puts defined?(ActiveSupport).inspect'
    out, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-rbundler/setup", "-e", code, chdir: ROOT)
    assert status.success?, out
    assert_includes out.lines[-2], "sql"
    assert_includes out.lines[-2], "sidekiq"
    assert_equal "nil", out.lines.last.strip
  end
end
