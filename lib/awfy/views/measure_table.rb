# frozen_string_literal: true

require "table_tennis"

module Awfy
  module Views
    # `awfy run --format table`: one row per test, one column per collector metric.
    class MeasureTable
      def self.render(doc)
        rows = doc["results"].map do |result|
          row = {"test" => "#{result["group"]}/#{result["report"]}/#{result["test"]}", "isolation" => result["isolation"]}
          result["collectors"].each do |key, data|
            (Collectors.lookup(key) || Collector).metrics(data).each { |name, value| row["#{key}.#{name}"] = value }
          end
          row
        end
        text = rows.empty? ? +"no results\n" : "#{TableTennis.new(rows, title: "awfy run: #{doc["label"]}")}\n"
        doc["failures"].each { text << "FAILED #{it["group"]}/#{it["report"]}/#{it["test"]}: #{it["error"]}\n" }
        text
      end
    end
  end
end
