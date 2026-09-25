# frozen_string_literal: true

module Awfy
  module Rails
    # SQL fingerprint: strip comments, quoted and numeric literals and $n binds, collapse IN
    # lists, squeeze whitespace. The app runs with prepared_statements: false, so values arrive
    # inlined in the SQL text.
    module SqlNormalizer
      # One left-to-right scan, so a comment marker inside a string or identifier and a quote
      # inside a comment are read as what they are. Postgres E'...' strings allow backslash
      # escapes, so E'it\'s' is one literal.
      LEXEME = %r{
        (?<escape_string>(?<!\w)[Ee]'(?:[^'\\]|\\.|'')*')
        | (?<string>'(?:[^']|'')*')
        | (?<identifier>"(?:[^"]|"")*")
        | (?<block_comment>/\*.*?\*/)
        | (?<line_comment>--[^\n]*)
      }mx
      BIND = /\$\d+/
      NUMBER = /\b\d+(?:\.\d+)?\b/
      IN_LIST = /\bIN\s*\(\s*\?(?:\s*,\s*\?)*\s*\)/i

      module_function

      def normalize(sql)
        sql.gsub(LEXEME) { replace_lexeme(::Regexp.last_match) }.gsub(BIND, "?").gsub(NUMBER, "?")
          .gsub(IN_LIST, "IN (?)").gsub(/\s+/, " ").strip
      end

      def replace_lexeme(match)
        if match[:identifier]
          match[:identifier]
        elsif match[:block_comment] || match[:line_comment]
          " "
        else
          "?"
        end
      end
    end
  end
end
