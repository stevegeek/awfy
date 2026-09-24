# frozen_string_literal: true

require "test_helper"

module Awfy
  class TestMemoryResult < Minitest::Test
    def create_memory_result(allocated_memsize: 1024, allocated_objects: 10, retained_memsize: 512, retained_objects: 5)
      MemoryResult.new(
        type: :memory,
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
          allocated_memsize: allocated_memsize,
          allocated_objects: allocated_objects,
          retained_memsize: retained_memsize,
          retained_objects: retained_objects
        }
      )
    end

    def test_inherits_from_result
      result = create_memory_result
      assert_kind_of Result, result
    end

    def test_type_is_memory
      result = create_memory_result
      assert_equal :memory, result.type
    end

    def test_result_data_contains_memory_metrics
      result = create_memory_result
      data = result.result_data

      assert data.key?(:allocated_memsize)
      assert data.key?(:allocated_objects)
      assert data.key?(:retained_memsize)
      assert data.key?(:retained_objects)
    end

    def test_allocated_memsize_accessible
      result = create_memory_result(allocated_memsize: 2048)
      assert_equal 2048, result.result_data[:allocated_memsize]
    end

    def test_allocated_objects_accessible
      result = create_memory_result(allocated_objects: 100)
      assert_equal 100, result.result_data[:allocated_objects]
    end

    def test_retained_memsize_accessible
      result = create_memory_result(retained_memsize: 1024)
      assert_equal 1024, result.result_data[:retained_memsize]
    end

    def test_retained_objects_accessible
      result = create_memory_result(retained_objects: 50)
      assert_equal 50, result.result_data[:retained_objects]
    end

    def test_result_class_for_memory_returns_memory_result
      klass = Result.result_class(:memory)
      assert_equal MemoryResult, klass
    end

    def test_can_serialize_and_deserialize
      result = create_memory_result
      serialized = result.serialize

      deserialized = Result.deserialize(serialized)

      assert_instance_of MemoryResult, deserialized
      assert_equal result.type, deserialized.type
      assert_equal result.group_name, deserialized.group_name
      assert_equal result.result_data[:allocated_memsize], deserialized.result_data[:allocated_memsize]
    end

    def test_baseline_flag
      baseline_result = create_memory_result
      assert baseline_result.baseline?
    end

    def test_control_flag
      result = create_memory_result
      refute result.control?
    end
  end
end
