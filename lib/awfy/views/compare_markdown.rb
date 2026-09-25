# frozen_string_literal: true

require "json"

module Awfy
  module Views
    # PR-ready Markdown for `awfy compare --format md`.
    class CompareMarkdown
      CELL_LIMIT = 160

      def self.render(doc) = new(doc).render

      def initialize(doc)
        @doc = doc
      end

      def render
        out = "# awfy compare: `#{@doc["baseline"]}` vs `#{@doc["against"]}`\n\n"
        @doc["results"].each { out << section(it) }
        @doc["missing"].each { out << "Only under `#{it["only_in"]}`: #{it["group"]} / #{it["report"]} / #{it["test"]}\n" }
        out
      end

      private

      def section(result)
        out = "## #{result["group"]} / #{result["report"]} / #{result["test"]}\n\n"
        out << outcome_line(result)
        out << warnings_list(result)
        out << collectors_missing_lines(result)
        out << "| Collector | Metric | #{@doc["baseline"]} | #{@doc["against"]} | Delta | % |\n"
        out << "|---|---|---:|---:|---:|---:|\n"
        result["collectors"].each do |key, data|
          data["metrics"].each do |name, row|
            pct = row["pct"].nil? ? "n/a" : format("%+.1f%%", row["pct"])
            out << "| #{key} | #{name} | #{number(row["base"])} | #{number(row["other"])} | #{number(row["delta"])} | #{pct} |\n"
          end
        end
        out << "\n"
        result["collectors"].each do |key, data|
          data["extras"].each { |title, rows| out << extra_table("#{key}: #{title}", rows) }
        end
        out
      end

      def outcome_line(result)
        return "Outcome: none recorded\n\n" if result["outcome_recorded"] == false
        return "Outcome: same\n\n" unless result["outcome_differs"]

        "**Outcome differs**: `#{JSON.generate(result["outcome"]["baseline"])}` vs `#{JSON.generate(result["outcome"]["against"])}`\n\n"
      end

      def warnings_list(result)
        warnings = result["warnings"] || []
        return "" if warnings.empty?

        out = +"**Environment differs**:\n\n"
        warnings.each { out << "- #{it["field"]}: `#{value(it["baseline"])}` vs `#{value(it["against"])}`\n" }
        out << "\n"
      end

      def collectors_missing_lines(result)
        missing = result["collectors_missing"] || {}
        return "" if missing.empty?

        missing.map { |key, label| "Collector `#{key}` only under `#{label}`\n" }.join << "\n"
      end

      def value(value) = value.nil? ? "n/a" : value.to_s

      def extra_table(title, rows)
        return "### #{title}\n\nnone\n\n" if rows.empty?

        headers = rows.flat_map(&:keys).uniq
        out = "### #{title}\n\n| #{headers.join(" | ")} |\n|#{"---|" * headers.size}\n"
        rows.each { |row| out << "| #{headers.map { cell(row[it]) }.join(" | ")} |\n" }
        out << "\n"
      end

      def cell(value)
        return "n/a" if value.nil?
        return number(value) if value.is_a?(Numeric)

        value.to_s.gsub("|", "\\|").tr("\n", " ")[0, CELL_LIMIT]
      end

      def number(value)
        case value
        when nil then "n/a"
        when Integer then value.to_s.gsub(/(\d)(?=(\d{3})+\z)/, '\1,')
        when Float then value.round(3).to_s
        else value.to_s
        end
      end
    end
  end
end
