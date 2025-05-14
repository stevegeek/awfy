# frozen_string_literal: true

# Simple test benchmark for integration testing
# Using minimal iterations for faster tests
# Iterations can be controlled via AWFY_TEST_ITERATIONS env var
iterations = ENV.fetch("AWFY_TEST_ITERATIONS", "10").to_i

Awfy.group "Test Group" do
  report "#+" do
    control "Integer" do
      iterations.times { 1 + 1 }
    end

    test "Float" do
      iterations.times { 1.0 + 1.0 }
    end
  end

  report "#*" do
    control "Integer" do
      iterations.times { 2 * 2 }
    end

    test "Float" do
      iterations.times { 2.0 * 2.0 }
    end
  end
end

# Another group for testing multiple groups
Awfy.group "Another Group" do
  report "#to_s" do
    control "Integer" do
      iterations.times { 123.to_s }
    end

    test "Float" do
      iterations.times { 123.45.to_s }
    end

    test "Array" do
      iterations.times { [1, 2, 3].to_s }
    end
  end
end
