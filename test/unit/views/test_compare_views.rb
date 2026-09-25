# frozen_string_literal: true

require "test_helper"

class CompareViewsTest < Minitest::Test
  DOC = {
    "baseline" => "master@435e4eb4", "against" => "fix@2facc52e",
    "results" => [{
      "group" => "G", "report" => "R", "test" => "t", "outcome_differs" => true,
      "outcome" => {"baseline" => {"total" => 11}, "against" => {"total" => 0}},
      "collectors" => {"sql" => {
        "metrics" => {"queries" => {"base" => 1482, "other" => 3, "delta" => -1479, "pct" => -99.8}},
        "extras" => {"n_plus_one_gone" => [{"sql" => "SELECT a | b", "frame" => "app/x.rb:1", "count" => 1312}], "n_plus_one_new" => []}
      }}
    }],
    "missing" => [{"group" => "G", "report" => "R", "test" => "u", "only_in" => "master@435e4eb4"}]
  }.freeze

  def test_markdown
    md = Awfy::Views::CompareMarkdown.render(DOC)
    assert_includes md, "| Collector | Metric | master@435e4eb4 | fix@2facc52e | Delta | % |"
    assert_includes md, "| sql | queries | 1,482 | 3 | -1,479 | -99.8% |"
    assert_includes md, "**Outcome differs**"
    assert_includes md, "SELECT a \\| b"
    assert_includes md, "### sql: n_plus_one_new\n\nnone"
    assert_includes md, "Only under `master@435e4eb4`: G / R / u"
  end

  def test_table
    text = Awfy::Views::CompareTable.render(DOC)
    assert_match(/queries/, text)
    assert_match(%r{outcome differs: G/R/t}, text)
  end

  NONE_RECORDED_DOC = {
    "baseline" => "a", "against" => "b",
    "results" => [{
      "group" => "G", "report" => "R", "test" => "t", "outcome_differs" => false, "outcome_recorded" => false,
      "outcome" => {"baseline" => nil, "against" => nil},
      "collectors" => {}
    }],
    "missing" => []
  }.freeze

  def test_markdown_says_none_recorded_when_neither_label_recorded_an_outcome
    md = Awfy::Views::CompareMarkdown.render(NONE_RECORDED_DOC)
    assert_includes md, "Outcome: none recorded"
    refute_includes md, "Outcome: same"
  end

  def test_table_says_none_recorded_when_neither_label_recorded_an_outcome
    text = Awfy::Views::CompareTable.render(NONE_RECORDED_DOC)
    assert_includes text, "Outcome: none recorded: G/R/t"
  end

  ENVIRONMENT_DOC = {
    "baseline" => "a", "against" => "b",
    "results" => [{
      "group" => "G", "report" => "R", "test" => "t", "outcome_differs" => false, "outcome_recorded" => true,
      "outcome" => {"baseline" => 1, "against" => 1},
      "warnings" => [
        {"field" => "isolation", "baseline" => "transaction", "against" => "none"},
        {"field" => "rails", "baseline" => "8.0.1", "against" => nil}
      ],
      "collectors" => {},
      "collectors_missing" => {"sql" => "a"}
    }],
    "missing" => []
  }.freeze

  def test_markdown_lists_environment_warnings
    md = Awfy::Views::CompareMarkdown.render(ENVIRONMENT_DOC)
    assert_includes md, "**Environment differs**"
    assert_includes md, "- isolation: `transaction` vs `none`"
    assert_includes md, "- rails: `8.0.1` vs `n/a`"
  end

  def test_markdown_lists_collectors_under_one_label_only
    md = Awfy::Views::CompareMarkdown.render(ENVIRONMENT_DOC)
    assert_includes md, "Collector `sql` only under `a`"
  end

  def test_table_lists_environment_warnings_and_collectors_under_one_label_only
    text = Awfy::Views::CompareTable.render(ENVIRONMENT_DOC)
    assert_includes text, "environment differs: G/R/t: isolation transaction vs none"
    assert_includes text, "environment differs: G/R/t: rails 8.0.1 vs n/a"
    assert_includes text, "collector sql only under a: G/R/t"
  end

  def test_views_accept_results_without_warnings_or_collectors_missing
    md = Awfy::Views::CompareMarkdown.render(DOC)
    refute_includes md, "Environment differs"
    text = Awfy::Views::CompareTable.render(DOC)
    refute_includes text, "environment differs"
  end
end
