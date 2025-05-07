# frozen_string_literal: true

require "uri"

module Awfy
  module Commands
    class Base < Literal::Object
      include Awfy::HasSession

      prop :group_names, _Nilable(_Array(String)), reader: :private
    end
  end
end
