# frozen_string_literal: true

module Awfy
  class Measurement < Literal::Data
    prop :group_name, String
    prop :report_name, String
    prop :test_name, String
    prop :isolation, String
    prop :outcome, _Any?
    prop :collectors, Hash

    def result_data = {"isolation" => isolation, "outcome" => outcome, "collectors" => collectors}

    def to_json_hash = {"group" => group_name, "report" => report_name, "test" => test_name}.merge(result_data)
  end
end
