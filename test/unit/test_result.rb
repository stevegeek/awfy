# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestResult < Minitest::Test
    def setup
      @timestamp = Time.now
      @result_attributes = {
        type: :ips,
        group_name: "Test Group",
        report_name: "#method_name",
        test_name: "test_case",
        runtime: Awfy::Runtimes::MRI,
        timestamp: @timestamp,
        branch: "main",
        commit_hash: "abc123",
        commit_message: "Test commit",
        ruby_version: "3.1.0",
        result_data: {
          iterations: 1000,
          runtime: 0.5,
          ips: 2000.0
        }
      }
    end

    def test_initialize_with_valid_attributes
      result = Result.new(**@result_attributes)

      assert_equal :ips, result.type
      assert_equal "Test Group", result.group_name
      assert_equal "#method_name", result.report_name
      assert_equal "test_case", result.test_name
      assert_equal Awfy::Runtimes::MRI, result.runtime
      assert_equal @timestamp, result.timestamp
      assert_equal "main", result.branch
      assert_equal "abc123", result.commit_hash
      assert_equal "Test commit", result.commit_message
      assert_equal "3.1.0", result.ruby_version
    end

    def test_result_id_auto_generated
      result = Result.new(**@result_attributes)

      # Result ID should be auto-generated if not provided
      refute_nil result.result_id
      assert result.result_id.is_a?(String)
      assert result.result_id.length > 0
    end

    def test_result_id_can_be_specified
      custom_id = "custom-result-id-123"
      result = Result.new(**@result_attributes.merge(result_id: custom_id))

      assert_equal custom_id, result.result_id
    end

    def test_result_data_keys_converted_to_symbols
      result = Result.new(**@result_attributes.merge(
        result_data: {"iterations" => 1000, "runtime" => 0.5}
      ))

      assert_equal 1000, result.result_data[:iterations]
      assert_equal 0.5, result.result_data[:runtime]
    end

    def test_label_from_result_data
      result = Result.new(**@result_attributes.merge(
        result_data: {label: "Custom Label"}
      ))

      assert_equal "Custom Label", result.label
    end

    def test_label_from_report_and_test_name
      result = Result.new(**@result_attributes)

      assert_equal "#method_name/test_case", result.label
    end

    def test_long_label
      result = Result.new(**@result_attributes)

      assert_equal "[Test Group/#method_name] test_case", result.long_label
    end

    def test_baseline_predicate
      result = Result.new(**@result_attributes.merge(baseline: true))
      assert result.baseline?

      result = Result.new(**@result_attributes.merge(baseline: false))
      refute result.baseline?
    end

    def test_control_predicate
      result = Result.new(**@result_attributes.merge(control: true))
      assert result.control?

      result = Result.new(**@result_attributes.merge(control: false))
      refute result.control?
    end

    def test_serialize
      result = Result.new(**@result_attributes.merge(baseline: true, control: false))
      serialized = result.serialize

      assert_equal "ips", serialized[:type]
      assert_equal 1, serialized[:baseline]
      assert_equal 0, serialized[:control]
      assert_equal @timestamp.to_i, serialized[:timestamp]
      assert_equal "mri", serialized[:runtime]
      assert_equal "Test Group", serialized[:group_name]
    end

    def test_deserialize_ips_result
      serialized = {
        type: "ips",
        group_name: "Test Group",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now.to_i,
        branch: "main",
        commit_hash: "abc",
        commit_message: "msg",
        ruby_version: "3.1.0",
        baseline: 1,
        control: 0,
        result_data: {ips: 1000}
      }

      result = Result.deserialize(serialized)

      assert_instance_of IPSResult, result
      assert_equal :ips, result.type
      assert_equal "Test Group", result.group_name
      assert result.baseline?
      refute result.control?
    end

    def test_deserialize_memory_result
      serialized = {
        type: "memory",
        group_name: "Test Group",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now.to_i,
        branch: "main",
        commit_hash: "abc",
        commit_message: "msg",
        ruby_version: "3.1.0",
        baseline: 0,
        control: 1,
        result_data: {memory: 1024}
      }

      result = Result.deserialize(serialized)

      assert_instance_of MemoryResult, result
      assert_equal :memory, result.type
      refute result.baseline?
      assert result.control?
    end

    def test_deserialize_handles_string_keys
      serialized = {
        "type" => "ips",
        "group_name" => "Test Group",
        "report_name" => "#method",
        "test_name" => "test",
        "runtime" => "mri",
        "timestamp" => Time.now.to_i,
        "branch" => "main",
        "commit_hash" => "abc",
        "commit_message" => "msg",
        "ruby_version" => "3.1.0",
        "baseline" => 0,
        "control" => 0,
        "result_data" => {"ips" => 1000}
      }

      result = Result.deserialize(serialized)

      assert_instance_of IPSResult, result
      assert_equal :ips, result.type
      assert_equal 1000, result.result_data[:ips]
    end

    def test_with_creates_new_instance_with_changes
      original = Result.new(**@result_attributes)
      modified = original.with(test_name: "new_test", branch: "feature")

      assert_equal "test_case", original.test_name
      assert_equal "new_test", modified.test_name
      assert_equal "main", original.branch
      assert_equal "feature", modified.branch
      assert_equal original.group_name, modified.group_name
    end

    def test_to_h_excludes_nil_values
      result = Result.new(**@result_attributes.merge(commit_message: nil))
      hash = result.to_h

      refute hash.key?(:commit_message)
      assert hash.key?(:group_name)
    end

    def test_runtime_conversion_from_string
      result = Result.new(**@result_attributes.merge(runtime: "yjit"))

      assert_equal Awfy::Runtimes::YJIT, result.runtime
    end

    def test_timestamp_conversion_from_integer
      timestamp_int = Time.now.to_i
      result = Result.new(**@result_attributes.merge(timestamp: timestamp_int))

      assert_instance_of Time, result.timestamp
      assert_equal timestamp_int, result.timestamp.to_i
    end

    def test_generate_new_result_id_format
      result = Result.new(**@result_attributes)
      result_id = result.result_id

      # Format: timestamp-hex-type-runtime-branch-group-report-control-baseline
      parts = result_id.split("-")
      assert parts.length > 5, "Result ID should have multiple parts"

      # Should contain the type
      assert result_id.include?("ips")

      # Should contain runtime
      assert result_id.include?("mri")

      # Should contain control/baseline indicators
      assert(result_id.include?("test") || result_id.include?("control"))
      assert(result_id.include?("result") || result_id.include?("baseline"))
    end

    def test_result_id_includes_encoded_components
      result = Result.new(**@result_attributes.merge(
        group_name: "Test Group With Spaces",
        report_name: "#method/with/slashes"
      ))

      result_id = result.result_id

      # Component with spaces should be URL encoded
      assert result_id.include?("Test+Group+With+Spaces")

      # Component with slashes should be URL encoded
      assert result_id.include?("%23method%2Fwith%2Fslashes")
    end

    def test_result_id_handles_nil_branch
      result = Result.new(**@result_attributes.merge(branch: nil))
      result_id = result.result_id

      # Should use "unknown" for nil branch
      assert result_id.include?("unknown")
    end
  end

  class TestIPSResult < Minitest::Test
    def test_ips_result_type
      result = IPSResult.new(
        type: :ips,
        group_name: "Test",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {samples: [100, 200, 300]}
      )

      assert_equal :ips, result.type
      assert_instance_of IPSResult, result
    end

    def test_ips_result_stores_samples
      result = IPSResult.new(
        type: :ips,
        group_name: "Test",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {samples: [100.0, 200.0, 300.0], ips: 200.0}
      )

      assert_equal [100.0, 200.0, 300.0], result.result_data[:samples]
      assert_equal 200.0, result.result_data[:ips]
    end

    def test_ips_result_inherits_from_result
      result = IPSResult.new(
        type: :ips,
        group_name: "Test",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {samples: [100.0, 200.0, 300.0]}
      )

      # Should have all Result methods
      assert_equal "#method/test", result.label
      assert_equal "[Test/#method] test", result.long_label
      refute_nil result.result_id
    end
  end

  class TestMemoryResult < Minitest::Test
    def test_memory_result_type
      result = MemoryResult.new(
        type: :memory,
        group_name: "Test",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {memory: 1024, objects: 50}
      )

      assert_equal :memory, result.type
      assert_instance_of MemoryResult, result
      assert_equal 1024, result.result_data[:memory]
      assert_equal 50, result.result_data[:objects]
    end

    def test_memory_result_inherits_from_result
      result = MemoryResult.new(
        type: :memory,
        group_name: "Test",
        report_name: "#method",
        test_name: "test",
        runtime: "mri",
        timestamp: Time.now,
        result_data: {memory: 2048}
      )

      # Should have all Result methods
      assert_equal "#method/test", result.label
      assert_equal "[Test/#method] test", result.long_label
      refute_nil result.result_id
    end
  end
end
