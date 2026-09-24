# frozen_string_literal: true

require "test_helper"
require "benchmark/ips"

module Awfy
  class TestIPSResult < Minitest::Test
    def create_ips_result(samples: [100.0, 110.0, 105.0, 95.0, 100.0])
      IPSResult.new(
        type: :ips,
        baseline: true,
        control: false,
        group_name: "test_group",
        report_name: "test_report",
        test_name: "test1",
        runtime: "mri",
        timestamp: Time.now,
        branch: "main",
        commit_hash: "abc123",
        commit_message: "Test commit",
        result_data: {
          measured_us: 1000.0,
          iter: 100,
          samples: samples,
          cycles: 10
        }
      )
    end

    def test_inherits_from_result
      result = create_ips_result
      assert_kind_of Result, result
    end

    def test_type_is_ips
      result = create_ips_result
      assert_equal :ips, result.type
    end

    def test_stats_returns_benchmark_ips_stats
      result = create_ips_result
      stats = result.stats
      assert_instance_of Benchmark::IPS::Stats::SD, stats
    end

    def test_central_tendency_returns_numeric
      result = create_ips_result
      ct = result.central_tendency
      assert_kind_of Numeric, ct
    end

    def test_central_tendency_is_average_of_samples
      samples = [100.0, 100.0, 100.0, 100.0, 100.0]
      result = create_ips_result(samples: samples)

      ct = result.central_tendency
      assert_in_delta 100.0, ct, 0.01
    end

    def test_result_data_contains_expected_keys
      result = create_ips_result
      data = result.result_data

      assert data.key?(:measured_us)
      assert data.key?(:iter)
      assert data.key?(:samples)
      assert data.key?(:cycles)
    end

    def test_samples_accessible
      samples = [1.0, 2.0, 3.0]
      result = create_ips_result(samples: samples)

      assert_equal samples, result.result_data[:samples]
    end

    def test_result_class_for_ips_returns_ips_result
      klass = Result.result_class(:ips)
      assert_equal IPSResult, klass
    end
  end
end
