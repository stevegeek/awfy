# frozen_string_literal: true

require "table_tennis"

module Awfy
  module Views
    class CompareTable
      def self.render(doc)
        rows = doc["results"].flat_map do |result|
          test = "#{result["group"]}/#{result["report"]}/#{result["test"]}"
          result["collectors"].flat_map do |key, data|
            data["metrics"].map do |name, row|
              {"test" => test, "collector" => key, "metric" => name, "baseline" => row["base"],
               "against" => row["other"], "delta" => row["delta"], "pct" => row["pct"]}
            end
          end
        end
        text = rows.empty? ? +"no common tests\n" : "#{TableTennis.new(rows, title: "#{doc["baseline"]} vs #{doc["against"]}")}\n"
        doc["results"].select { it["outcome_recorded"] == false }.each { text << "Outcome: none recorded: #{it["group"]}/#{it["report"]}/#{it["test"]}\n" }
        doc["results"].select { it["outcome_differs"] }.each { text << "outcome differs: #{it["group"]}/#{it["report"]}/#{it["test"]}\n" }
        doc["results"].each do |result|
          test = "#{result["group"]}/#{result["report"]}/#{result["test"]}"
          (result["warnings"] || []).each do |warning|
            text << "environment differs: #{test}: #{warning["field"]} #{value(warning["baseline"])} vs #{value(warning["against"])}\n"
          end
          (result["collectors_missing"] || {}).each { |key, label| text << "collector #{key} only under #{label}: #{test}\n" }
        end
        doc["missing"].each { text << "only under #{it["only_in"]}: #{it["group"]}/#{it["report"]}/#{it["test"]}\n" }
        text
      end

      def self.value(value) = value.nil? ? "n/a" : value.to_s
    end
  end
end
