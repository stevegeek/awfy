# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# Rails production boot calls Zeitwerk::Loader.eager_load_all, which eager-loads awfy too
# when the awfy CLI loaded it first. Every file under lib/awfy must therefore eager-load.
class EagerLoadTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def ruby(code)
    Open3.capture2e(RbConfig.ruby, "-Ilib", "-rbundler/setup", "-e", code, chdir: ROOT)
  end

  def test_the_gem_eager_loads
    out, status = ruby('require "awfy"; Awfy::LOADER.eager_load; puts "EAGER_OK"')
    assert status.success?, out
    assert_includes out, "EAGER_OK"
  end

  def test_awfy_rails_is_outside_zeitwerk
    out, status = ruby('require "awfy"; Awfy::LOADER.eager_load; puts defined?(Awfy::Rails).inspect')
    assert status.success?, out
    assert_equal "nil", out.lines.last.strip
  end
end
