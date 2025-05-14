# frozen_string_literal: true

module Awfy
  class Runtimes < Literal::Enum(String)
    MRI = new("mri")
    YJIT = new("yjit")
  end
end
