# frozen_string_literal: true

require "fileutils"

module Awfy
  # What a collector knows about the call it measures. pass 0 is the warm-up.
  class CollectorContext < Literal::Data
    prop :group_name, String
    prop :report_name, String
    prop :test_name, String
    prop :label, String
    prop :pass, Integer
    prop :artefacts_dir, String

    def slug = [group_name, report_name, test_name].map { it.gsub(/[^A-Za-z0-9_.]+/, "_") }.join("-")

    def artefact_path(suffix)
      FileUtils.mkdir_p(artefacts_dir)
      File.join(artefacts_dir, "#{slug}.#{suffix}")
    end
  end
end
