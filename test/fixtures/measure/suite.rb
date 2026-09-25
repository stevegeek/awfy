# frozen_string_literal: true

# Fixture for `awfy run`/`awfy compare`. AWFY_FIXTURE_ITEMS changes the work and the outcome.
items = Integer(ENV.fetch("AWFY_FIXTURE_ITEMS", "1000"))

Awfy.group "Fixture Measure" do
  isolate :none

  report "#build" do
    test "strings" do
      Array.new(items) { |i| "item-#{i}" }
      Struct.new(:awfy_outcome).new({"items" => items})
    end
  end
end
