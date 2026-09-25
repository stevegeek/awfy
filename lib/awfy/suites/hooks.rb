# frozen_string_literal: true

module Awfy
  module Suites
    # Hooks of one group or one report. Mutable, unlike Group/Report (Literal::Data).
    class Hooks < Literal::Object
      prop :setup, _Nilable(Proc), reader: :public, writer: :public
      prop :before_each, _Nilable(Proc), reader: :public, writer: :public
      prop :after_each, _Nilable(Proc), reader: :public, writer: :public
      prop :isolate, _Nilable(Symbol), reader: :public, writer: :public
    end
  end
end
