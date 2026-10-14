# frozen_string_literal: true

require "test_helper"

class ChecksTest < Minitest::Test
  # Checks are recorded only while a PassRunner measures
  def setup = Thread.current[Awfy::PassRunner::ACTIVE_RUN_KEY] = :measuring

  def teardown
    Thread.current[Awfy::PassRunner::ACTIVE_RUN_KEY] = nil
    Awfy::Checks.reset!
  end

  def test_records_every_check_in_order
    Awfy::Checks.record("first", true)
    Awfy::Checks.record(:second, nil, 42)
    assert_equal [
      {"name" => "first", "pass" => true, "detail" => nil},
      {"name" => "second", "pass" => false, "detail" => "42"}
    ], Awfy::Checks.recorded
  end

  def test_reset_clears_the_checks
    Awfy::Checks.record("x", true)
    Awfy::Checks.reset!
    assert_equal [], Awfy::Checks.recorded
  end

  def test_a_check_outside_a_measure_is_ignored
    Thread.current[Awfy::PassRunner::ACTIVE_RUN_KEY] = nil
    Awfy::Checks.record("x", false)
    assert_equal [], Awfy::Checks.recorded
  end
end
