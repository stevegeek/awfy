# frozen_string_literal: true

require "test_helper"

class IsolationTest < Minitest::Test
  module FakeTransaction
    def self.available? = true

    def self.wrap = yield
  end

  def with_strategies(strategies)
    saved = Awfy::Isolation.strategies.dup
    Awfy::Isolation.instance_variable_set(:@strategies, strategies)
    yield
  ensure
    Awfy::Isolation.instance_variable_set(:@strategies, saved)
  end

  def test_none_and_snapshot_run_the_block
    assert_equal 3, Awfy::Isolation.resolve(:none).last.wrap { 3 }
    assert_equal [:snapshot, Awfy::Isolation::None], Awfy::Isolation.resolve(:snapshot)
  end

  def test_default_is_none_without_a_transaction_strategy
    with_strategies(none: Awfy::Isolation::None, snapshot: Awfy::Isolation::None) do
      assert_equal :none, Awfy::Isolation.resolve(nil).first
      assert_raises(Awfy::Errors::IsolationUnavailableError) { Awfy::Isolation.resolve(:transaction) }
    end
  end

  def test_default_is_transaction_when_registered_and_available
    with_strategies(none: Awfy::Isolation::None, snapshot: Awfy::Isolation::None, transaction: FakeTransaction) do
      assert_equal [:transaction, FakeTransaction], Awfy::Isolation.resolve(nil)
    end
  end
end
