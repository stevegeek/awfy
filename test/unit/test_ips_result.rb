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
          measured_us: 1_000_000.0,
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

    # benchmark-ips 2.14 builds SD from the samples alone.
    class SamplesOnlySD
      attr_reader :args

      def initialize(samples)
        @args = [samples]
      end
    end

    # benchmark-ips 2.15 also needs the measured time and the iteration count.
    class TimedSD
      attr_reader :args

      def initialize(samples, measured_us, iterations)
        @args = [samples, measured_us, iterations]
      end
    end

    def test_stats_for_passes_only_samples_to_a_one_argument_sd
      stats = IPSResult.stats_for({samples: [1.0, 2.0], measured_us: 500.0, iter: 7}, sd_class: SamplesOnlySD)

      assert_equal [[1.0, 2.0]], stats.args
    end

    def test_stats_for_passes_measured_time_and_iterations_to_a_three_argument_sd
      stats = IPSResult.stats_for({samples: [1.0, 2.0], measured_us: 500.0, iter: 7}, sd_class: TimedSD)

      assert_equal [[1.0, 2.0], 500.0, 7], stats.args
    end

    def test_stats_for_derives_timing_from_samples_when_result_lacks_it
      stats = IPSResult.stats_for({samples: [100.0, 300.0]}, sd_class: TimedSD)

      samples, measured_us, iterations = stats.args
      assert_equal [100.0, 300.0], samples
      assert_in_delta 200.0, 1_000_000.0 * iterations / measured_us, 0.001
    end

    def test_central_tendency_without_timing_data_is_average_of_samples
      result = IPSResult.new(
        type: :ips,
        group_name: "test_group",
        report_name: "test_report",
        test_name: "test1",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {samples: [100.0, 300.0]}
      )

      assert_in_delta 200.0, result.central_tendency, 0.01
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
