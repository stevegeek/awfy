# Benchmark Suite Guide

This guide explains how to set up and write benchmarks using Awfy's DSL.

## Available Profiling Gems

Awfy integrates with several Ruby profiling gems:

- [benchmark-ips](https://rubygems.org/gems/benchmark-ips) - For iterations per second benchmarking
- [memory_profiler](https://rubygems.org/gems/memory_profiler) - For memory allocation profiling
- [stackprof](https://rubygems.org/gems/stackprof) - For CPU profiling
- [vernier](https://rubygems.org/gems/vernier) - For flamegraph generation

## Directory Structure

By default, Awfy expects the following directory structure:

```
benchmarks/
  setup.rb           # Optional setup file
  tests/             # Your benchmark files
    my_benchmark.rb
    another_test.rb
```

The paths can be customized via config files or CLI options:


Eg in `.awfy.json`:

```json
{
  "setup_file_path": "./benchmarks/setup",
  "tests_path": "./benchmarks/tests"
}
```


## Setup File

The optional `setup.rb` file runs before loading any benchmark files. Use it to:

- Require dependencies
- Set up test data
- Configure environment
- Define helper methods

Example setup file:

```ruby
# benchmarks/setup.rb
require "cool_thing"
# Load your application code
require_relative "../lib/my_app"

# Create test data
SAMPLE_DATA = (1..1000).to_a.freeze

# Helper methods
def create_test_object
  MyApp::TestObject.new(data: SAMPLE_DATA)
end
```

## Writing Benchmarks

Awfy uses a simple DSL to define benchmark suites. Here's the structure:

```ruby
# Group related benchmarks together
Awfy.group "MyFeature" do
  # A report represents one logical thing under test, eg it could be a method
  report "#my_method" do
    # Optionally do setup outside the benchmark blocks
    obj = create_test_object
    alt_obj = create_alternative_object

    # We now define 'tests', which are blocks of code that will be benchmarked
    
    # 'Control' blocks are optional and essentially indicate that this test is a "control", ie you are not expecting it 
    # to change between runs
    control "Current Implementation" do
      obj.my_method
    end

    # Test blocks benchmark whatever you are interested in to consider as the "baseline" for this report.
    # There must be at least one test block in a report.
    test "New Implementation" do
      alt_obj.my_method
    end

    # Optional: Alternative implementations are the same as "tests" but the naming convention is different to
    # help you identify them in the suite as "alternative" tests (eg testing a different algorithm).
    alternative "Another Approach" do
      alt_obj.different_method
    end

    # Optional: Add assertions about performance - NOT IMPLEMENTED YET
    assert(
      memory: { total_allocated_memory: { eq: 0.0 } },
      ips: { within: { times: 2.0, of: "Current Implementation" } }
    )
  end
end
```

### DSL Methods

#### `group(name, &block)`
Groups related benchmarks together. Use descriptive names like "Array Operations" or "JSON Parsing".

#### `report(name, &block)`
Defines a set of related tests, typically focusing on one method or feature. Name it after the method being tested, e.g. "#parse" or "#to_json".

#### `control(name, &block)`
Benchmarks an existing implementation that won't change. Use this for:
- Standard library methods
- Third-party gems
- Current implementation (when working on an alternative)

#### `test(name, &block)`
Benchmarks your main implementation under test. This is typically:
- Your new implementation
- The code you're trying to optimize
- The feature you're developing

#### `alternative(name, &block)`
Benchmarks an alternative implementation. This is useful for:
- Comparing different algorithms you are working on at the same time
- Exploring different approaches to a problem

Especially when you dont consider the code being benchmarked to be a "control".


## Debugging Tips

You can run your suite of tests without benchmarking to debug issues.

```bash
bundle exec awfy suite debug --test-time=0
```
