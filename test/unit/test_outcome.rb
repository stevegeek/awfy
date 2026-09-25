# frozen_string_literal: true

require "test_helper"

class OutcomeTest < Minitest::Test
  def teardown = Awfy::Outcome.reset!

  def test_return_value_with_awfy_outcome_wins
    Awfy::Outcome.record({"recorded" => true})
    value = Struct.new(:awfy_outcome).new({items: 2})
    assert_equal({"items" => 2}, Awfy::Outcome.resolve(value, {}))
  end

  def test_recorded_block_gets_the_collected_data
    Awfy::Outcome.record { |collected| collected["sidekiq"]["total"] }
    assert_equal 11, Awfy::Outcome.resolve(:ignored, {"sidekiq" => {"total" => 11}})
  end

  def test_nothing_recorded_is_nil
    Awfy::Outcome.reset!
    assert_nil Awfy::Outcome.resolve(42, {})
  end
end
