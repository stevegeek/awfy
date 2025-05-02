# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"
require "ostruct"

# Mock Shell class for testing views
class MockShell
  attr_reader :messages, :errors

  def initialize
    @messages = []
    @errors = []
  end

  def say(message = "", color = nil)
    @messages << {message: message, color: color}
  end

  def say_error(message)
    @errors << message
  end
end

# Mock options class for testing views
class MockOptions
  attr_accessor :verbose, :show_summary, :summary_order, :quiet

  def initialize(options = {})
    @verbose = options[:verbose] || false
    @show_summary = options[:show_summary] || true
    @summary_order = options[:summary_order] || "desc"
    @quiet = options[:quiet] || false
  end

  def verbose?
    @verbose
  end

  def show_summary?
    @show_summary
  end

  def quiet?
    @quiet
  end
end

# Test case base class with common setup for view tests
class ViewTestCase < Minitest::Test
  def setup
    @shell = MockShell.new
    @options = MockOptions.new
  end

  # Generate test results for IPS benchmarks
  def generate_ips_results(num_results = 2, with_baseline = true)
    results = []

    (1..num_results).each do |i|
      is_baseline = with_baseline && i == 1

      result = {
        branch: "main",
        runtime: i.even? ? "yjit" : "mri",
        test_name: "Test #{i}",
        is_baseline: is_baseline,
        samples: [1000 * i, 1050 * i, 1100 * i, 1050 * i, 1000 * i],
        iter: 1000 * i
      }

      results << result
    end

    baseline = results.find { |r| r[:is_baseline] } || results.first

    [results, baseline]
  end

  # Generate test results for memory benchmarks
  def generate_memory_results(num_results = 2, with_baseline = true)
    results = []

    (1..num_results).each do |i|
      is_baseline = with_baseline && i == 1

      result = {
        branch: "main",
        runtime: i.even? ? "yjit" : "mri",
        test_name: "Test #{i}",
        is_baseline: is_baseline,
        measurement: OpenStruct.new(
          allocated: 1000000 * i,
          retained: 500000 * i,
          objects: OpenStruct.new(allocated: 10000 * i),
          strings: OpenStruct.new(allocated: 5000 * i)
        )
      }

      results << result
    end

    baseline = results.find { |r| r[:is_baseline] } || results.first

    [results, baseline]
  end

  # Generate results by commit for HighlightsView tests
  def generate_results_by_commit(num_commits = 3, with_mri = true, with_yjit = true)
    results = {}

    (1..num_commits).each do |i|
      commit = "000commit#{i}"
      results[commit] = {
        metadata: {
          commit_message: "Commit message #{i}"
        }
      }

      if with_mri
        results[commit][:mri] = [
          {"item" => "test1", "ips" => 1000.0 * i, "memory" => {"memsize" => 100000 * i, "objects" => 1000 * i}},
          {"item" => "test2", "ips" => 2000.0 * i, "memory" => {"memsize" => 200000 * i, "objects" => 2000 * i}}
        ]
      end

      if with_yjit
        results[commit][:yjit] = [
          {"item" => "test1", "ips" => 1500.0 * i, "memory" => {"memsize" => 100000 * i, "objects" => 1000 * i}},
          {"item" => "test2", "ips" => 3000.0 * i, "memory" => {"memsize" => 200000 * i, "objects" => 2000 * i}}
        ]
      end
    end

    sorted_commits = results.keys.sort

    [sorted_commits, results]
  end
end
