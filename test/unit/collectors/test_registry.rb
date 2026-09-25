# frozen_string_literal: true

require "test_helper"

class CollectorRegistryTest < Minitest::Test
  class Probe < Awfy::Collector
    def self.key = "registry_probe"
  end

  def test_core_keys_are_registered
    %w[timing gc rss memory_profiler].each { assert_includes Awfy::Collectors.keys, it }
    assert_equal Awfy::Collectors::Timing, Awfy::Collectors.fetch("timing")
  end

  def test_register_and_lookup
    Awfy::Collectors.register(Probe)
    assert_equal Probe, Awfy::Collectors.lookup("registry_probe")
    assert_nil Awfy::Collectors.lookup("never_registered")
  end

  def test_unknown_key_lists_the_known_keys
    error = assert_raises(Awfy::Errors::UnknownCollectorError) { Awfy::Collectors.fetch("nope") }
    assert_match(/Unknown collector 'nope'/, error.message)
    assert_match(/timing/, error.message)
    assert_match(%r{awfy/rails}, error.message)
  end

  def test_normalize_gives_string_keys
    assert_equal({"a" => {"b" => 1}}, Awfy::Collectors.normalize({a: {b: 1}}))
  end
end
