# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"

class RunMetaTest < Minitest::Test
  def teardown = Awfy::RunMeta.reset!

  def test_snapshot_has_ruby_and_merged_values
    # standard:disable Performance/RedundantMerge -- Awfy::RunMeta is not a Hash, it has no #[]=
    Awfy::RunMeta.merge!(rails_env: "production")
    # standard:enable Performance/RedundantMerge
    meta = Awfy::RunMeta.snapshot
    assert_equal RUBY_DESCRIPTION, meta["ruby"]
    assert_includes [true, false], meta["yjit"]
    assert_equal "production", meta["rails_env"]
  end

  def test_output_writer_creates_the_directory
    Dir.mktmpdir do |dir|
      path = File.join(dir, "a/b.json")
      Awfy::OutputWriter.write(JSON.generate({"x" => 1}), output: path)
      assert_equal({"x" => 1}, JSON.parse(File.read(path)))
    end
  end
end
