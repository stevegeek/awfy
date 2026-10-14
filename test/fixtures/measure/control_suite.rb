# frozen_string_literal: true

# Fixture for a control in `awfy run`/`awfy compare`. AWFY_FIXTURE_ITEMS changes its outcome;
# AWFY_FIXTURE_CALLS, when set, is a file that gets one line per call.
items = Integer(ENV.fetch("AWFY_FIXTURE_ITEMS", "1000"))
calls = ENV["AWFY_FIXTURE_CALLS"]

Awfy.group "Fixture Control" do
  isolate :none

  report "#build" do
    control "unchanged" do
      File.write(calls, "call\n", mode: "a") if calls
      Struct.new(:awfy_outcome).new({"items" => items})
    end
  end
end
