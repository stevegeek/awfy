# frozen_string_literal: true

require_relative "rails_test_helper"

class TransactionIsolationTest < Minitest::Test
  def setup
    RailsTestHelper.connect!
    AwfyWidget.delete_all
    AwfyWidget.committed.clear
  end

  def isolation = Awfy::Rails::TransactionIsolation

  def test_registered_and_available
    assert_equal [:transaction, isolation], Awfy::Isolation.resolve(:transaction)
    assert isolation.available?
  end

  def test_rolls_back_and_after_commit_still_fires
    value = isolation.wrap do
      AwfyWidget.create!(name: "a")
      :done
    end
    assert_equal :done, value
    assert_equal 0, AwfyWidget.count
    assert_equal 1, AwfyWidget.committed.size
  end

  def test_rolls_back_when_the_block_raises
    assert_raises(RuntimeError) do
      isolation.wrap do
        AwfyWidget.create!(name: "a")
        raise "boom"
      end
    end
    assert_equal 0, AwfyWidget.count
    refute ActiveRecord::Base.lease_connection.transaction_open?
  end

  def test_a_unit_that_ends_the_outer_transaction_is_reported
    assert_raises(Awfy::Errors::IsolationBrokenError) do
      isolation.wrap { ActiveRecord::Base.lease_connection.rollback_transaction }
    end
  end
end
