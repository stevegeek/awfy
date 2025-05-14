# frozen_string_literal: true

# This file contains benchmark tests that are CPU bound,
# to test the behavior of runners like ForkedRunner.

require "digest"

Awfy.group "Light Hash Workload" do
  report "SHA256 Hash Computation" do
    test "Small Hash Computation" do
      data = "x" * 1000
      100_000.times do
        Digest::SHA256.hexdigest(data)
      end
    end
  end
end

Awfy.group "Medium Hash Workload" do
  report "SHA256 Hash Computation" do
    test "Medium Hash Computation" do
      data = "x" * 5000
      100_000.times do
        Digest::SHA256.hexdigest(data)
      end
    end
  end
end

Awfy.group "Heavy Hash Workload" do
  report "SHA256 Hash Computation" do
    test "Large Hash Computation" do
      data = "x" * 10000
      100_000.times do
        Digest::SHA256.hexdigest(data)
      end
    end
  end
end

Awfy.group "Variable Hash Workload" do
  report "SHA256 Hash Computation" do
    test "Variable Hash Computation" do
      sizes = [1000, 5000, 10000, 100_000]
      iterations = [500, 1000, 1500]

      data = "x" * sizes.sample
      iterations.sample.times do
        Digest::SHA256.hexdigest(data)
      end
    end
  end
end

Awfy.group "Fibonacci Computation" do
  report "Recursive Fibonacci" do
    test "Small Fibonacci" do
      fib = ->(n) { (n < 2) ? n : fib[n - 1] + fib[n - 2] }
      fib[20]
    end
  end
end

Awfy.group "Prime Number Generation" do
  report "Prime Sieve" do
    test "Sieve of Eratosthenes" do
      max = 10_000_000
      sieve = Array.new(max, true)
      sieve[0] = sieve[1] = false

      (2..Math.sqrt(max).to_i).each do |i|
        if sieve[i]
          (i * i...max).step(i) do |j|
            sieve[j] = false
          end
        end
      end

      # Count primes
      sieve.count(true)
    end
  end
end

Awfy.group "Array Sorting" do
  report "Sort Performance" do
    test "Large Array Sort" do
      array = Array.new(20_000_000) { rand(100000) }
      array.sort
    end
  end
end

Awfy.group "String Manipulation" do
  report "String Operations" do
    test "String Concatenation" do
      result = ""
      100_000.times do |i|
        result += "#{i}"
      end
    end
  end
end
