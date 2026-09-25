# frozen_string_literal: true

require "test_helper"

class HooksDslTest < Minitest::Test
  def build(&block)
    suite = Awfy::Suite.new
    suite.group("G", &block)
    suite.groups.first
  end

  def test_group_and_report_level_hooks
    group = build do
      before_each { :group }
      isolate :none
      report("R") do
        before_each { :report }
        isolate :snapshot
        test("t") {}
      end
    end
    assert_equal :group, group.hooks.before_each.call
    assert_equal :none, group.hooks.isolate
    assert_equal :report, group.reports.first.hooks.before_each.call
    assert_equal :snapshot, group.reports.first.hooks.isolate
  end

  def test_hooks_after_a_report_block_go_to_the_group
    group = build do
      report("R") { test("t") {} }
      after_each { :late }
    end
    assert_equal :late, group.hooks.after_each.call
    assert_nil group.reports.first.hooks.after_each
  end

  def test_isolate_rejects_unknown_names
    error = assert_raises(ArgumentError) { build { isolate :rollback } }
    assert_match(/:transaction, :none, :snapshot/, error.message)
  end

  def test_defaults_are_nil
    group = build { report("R") { test("t") {} } }
    assert_nil group.hooks.setup
    assert_nil group.reports.first.hooks.isolate
  end
end
