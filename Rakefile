# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.warning = false  # Disable Ruby warnings
end

require "standard/rake"

# Coverage task
desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "1"
  Rake::Task["test"].invoke
end

task default: %i[test standard]
