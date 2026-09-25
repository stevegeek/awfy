# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "zlib"
require "json"

class VernierCollectorTest < Minitest::Test
  def test_writes_a_gzipped_profile_and_records_the_path
    Dir.mktmpdir do |dir|
      context = Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass: 2, artefacts_dir: dir)
      collector = Awfy::Collectors::Vernier.new
      value = collector.around(context) do
        collector.start(context)
        200_000.times.sum
        :done
      end
      data = collector.stop(context)
      assert_equal :done, value
      assert Awfy::Collectors::Vernier.heavy?
      assert data["path"].end_with?("G-R-t.vernier.json.gz")
      Zlib::GzipReader.open(data["path"]) { |gz| assert JSON.parse(gz.read).key?("meta") }
      assert data.key?("samples")
      assert_equal Awfy::Collectors::Vernier, Awfy::Collectors.fetch("vernier")
    end
  end

  def test_a_raising_block_leaves_no_json_debris_and_no_path_reported
    Dir.mktmpdir do |dir|
      context = Awfy::CollectorContext.new(group_name: "G", report_name: "R", test_name: "t", label: "l", pass: 2, artefacts_dir: dir)
      collector = Awfy::Collectors::Vernier.new
      assert_raises(RuntimeError) do
        collector.around(context) do
          collector.start(context)
          raise "boom"
        end
      end
      assert_empty Dir.children(dir), "no uncompressed .json (or any other) debris is left behind"
      data = collector.stop(context)
      refute data.key?("path"), "a .gz file that was never written must not be reported"
    end
  end
end
