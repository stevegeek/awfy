# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in awfy.gemspec
gemspec

gem "rake", "~> 13.0"

gem "minitest", "~> 5.16"

gem "standard", "~> 1.3"

gem "simplecov", "~> 0.22", require: false

# For example benchmarks suite
gem "monotime"

# For test mocks and compatibility with Ruby 3.5+
gem "ostruct"

# awfy/rails tests (not runtime dependencies: the Rails layer uses the host app's Rails)
gem "activerecord", ">= 7.2"
gem "activesupport", ">= 7.2"
gem "actionpack", ">= 7.2"
gem "warden", "~> 1.2"
