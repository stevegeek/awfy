# frozen_string_literal: true

module Awfy
  class Measurement < Literal::Data
    prop :group_name, String
    prop :report_name, String
    prop :test_name, String
    prop :isolation, String
    prop :outcome, _Any?
    prop :checks, _Array(Hash), default: -> { [] }
    prop :collectors, Hash

    # "checks" only when the test recorded any, so results without checks keep their old shape
    def result_data
      data = {"isolation" => isolation, "outcome" => outcome, "collectors" => collectors}
      checks.empty? ? data : data.merge("checks" => checks)
    end

    def failed_checks = checks.reject { it["pass"] }

    def to_json_hash = {"group" => group_name, "report" => report_name, "test" => test_name}.merge(result_data)
  end
end
