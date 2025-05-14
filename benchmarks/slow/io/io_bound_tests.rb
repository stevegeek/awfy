# frozen_string_literal: true

require "monotime"

# This file contains benchmark tests that are primarily I/O bound,
# to test the behavior of runners like ThreadRunner.
# The "I/O" operations are simulated using `sleep`.

Awfy.group "IO: Milli Sleeps 1" do
  report "Simulated I/O - Milli Sleeps" do
    test "lots of small sleeps" do
      3000.times do
        Monotime::Duration.millis(1).sleep
      end
    end
  end
end

Awfy.group "IO: Milli Sleeps 2" do
  report "Simulated I/O - Milli Sleeps" do
    test "5000 x 1ms sleeps" do
      5000.times do
        Monotime::Duration.millis(1).sleep
      end
    end
  end
end

Awfy.group "IO: Centi Sleeps" do
  report "Simulated I/O - Centi Sleeps" do
    test "10 x 10ms sleeps" do
      10.times do
        Monotime::Duration.millis(10).sleep
      end
    end
  end
end
