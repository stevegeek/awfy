# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "json"

# boot! runs in a subprocess: it defines ::Rails, which must not leak into other tests.
class RailsBootTest < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_boot_requires_the_environment_and_records_meta
    Dir.mktmpdir do |app|
      FileUtils.mkdir_p(File.join(app, "config"))
      File.write(File.join(app, "config/environment.rb"), <<~RUBY)
        module Rails
          def self.env = "production"
          def self.version = "8.1.3.1"
          def self.application = :app
        end
      RUBY
      code = 'require "awfy/rails"; Awfy::Rails.boot!(ARGV[0]); puts JSON.generate(Awfy::RunMeta.snapshot)'
      out, status = Open3.capture2e({"LD_PRELOAD" => "/usr/lib/libjemalloc.so.2"}, RbConfig.ruby, "-Ilib", "-rbundler/setup", "-rjson", "-e", code, app, chdir: ROOT)
      assert status.success?, out
      meta = JSON.parse(out.lines.last)
      assert_equal "production", meta["rails_env"]
      assert_equal "8.1.3.1", meta["rails"]
      assert_equal true, meta["jemalloc"]
    end
  end
end
