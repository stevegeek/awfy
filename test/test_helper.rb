# frozen_string_literal: true

# SimpleCov must be loaded before any application code
if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"

  SimpleCov.start do
    add_filter "/test/"
    add_filter "/vendor/"

    # Group coverage by type
    add_group "Commands", "lib/awfy/cli_commands"
    add_group "Commands (legacy)", "lib/awfy/commands"
    add_group "Runners", "lib/awfy/runners"
    add_group "Stores", "lib/awfy/stores"
    add_group "Views", "lib/awfy/views"
    add_group "Suites", "lib/awfy/suites"
    add_group "Jobs", "lib/awfy/jobs"
    add_group "Core", "lib/awfy"

    # Set minimum coverage threshold (warning only, not failing build yet)
    # minimum_coverage 80  # Uncomment when we reach this goal
    # minimum_coverage_by_file 50  # Uncomment when we reach this goal

    # Print coverage summary
    at_exit do
      puts "\n" + "=" * 80
      puts "CODE COVERAGE SUMMARY"
      puts "=" * 80
      puts "Coverage report: file://#{SimpleCov.coverage_dir}/index.html"
      puts "=" * 80
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "awfy"

# Eagerly load all classes so coverage also reports files no test touches
Awfy::LOADER.eager_load if ENV["COVERAGE"] || ENV["CI"]

require "minitest/autorun"
