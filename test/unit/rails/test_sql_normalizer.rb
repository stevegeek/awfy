# frozen_string_literal: true

require_relative "rails_test_helper"

class SqlNormalizerTest < Minitest::Test
  def n(sql) = Awfy::Rails::SqlNormalizer.normalize(sql)

  def test_numbers_strings_and_binds
    assert_equal 'SELECT "teams".* FROM "teams" WHERE "teams"."id" = ? LIMIT ?',
      n('SELECT "teams".* FROM "teams" WHERE "teams"."id" = 42 LIMIT 1')
    assert_equal n(%(SELECT * FROM t WHERE esp = 'hubspot')), n(%(SELECT * FROM t WHERE esp = 'it''s'))
    assert_equal "SELECT * FROM t WHERE id = ?", n("SELECT * FROM t WHERE id = $1")
  end

  def test_in_lists_of_any_length_collapse
    assert_equal n("SELECT * FROM t WHERE id IN (1, 2, 3)"), n("SELECT * FROM t WHERE id IN (4,5)")
    assert_equal "SELECT * FROM t WHERE id IN (?)", n("SELECT * FROM t WHERE id IN ($1, $2)")
  end

  def test_identifiers_with_digits_and_comments_and_whitespace
    assert_equal 'SELECT "t0"."r1" FROM t', n("/*action:index*/ SELECT \"t0\".\"r1\"\n   FROM t")
  end

  def test_postgres_escape_strings_become_a_placeholder
    assert_equal "SELECT * FROM t WHERE name = ? AND id = ?",
      n(%q(SELECT * FROM t WHERE name = E'it\'s' AND id = 7))
    assert_equal "SELECT * FROM t WHERE a = ? AND b = ?",
      n(%q(SELECT * FROM t WHERE a = e'line\nbreak \\\\' AND b = E'x''y'))
    assert_equal n("SELECT * FROM t WHERE name = 'plain'"), n(%q(SELECT * FROM t WHERE name = E'esc\'aped'))
  end

  def test_line_comments_are_removed
    assert_equal "SELECT * FROM t WHERE id = ?",
      n("SELECT * -- all columns\nFROM t\n-- filter: don't drop\nWHERE id = 1 -- trailing")
    assert_equal n("SELECT * FROM t WHERE id = 1"), n("SELECT * FROM t WHERE id = 2 -- app:web")
  end

  def test_comment_markers_inside_literals_and_identifiers_are_kept
    assert_equal "SELECT * FROM t WHERE note = ? AND id = ?", n("SELECT * FROM t WHERE note = 'a -- b' AND id = 1")
    assert_equal "SELECT * FROM t WHERE note = ? AND id = ?", n("SELECT * FROM t WHERE note = '/* x */' AND id = 1")
    assert_equal 'SELECT "a--b" FROM t WHERE id = ?', n('SELECT "a--b" FROM t WHERE id = 1')
    assert_equal "SELECT * FROM t WHERE id = ?", n("/* don't */ SELECT * FROM t WHERE id = 1")
  end
end
