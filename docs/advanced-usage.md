# Advanced Usage Guide

This guide covers advanced features and usage patterns for Awfy.

## Branch Comparison

Compare performance between git branches:

```bash
bundle exec awfy ips Arrays "#map" --compare-with=main
```

Include control blocks in comparison:

```bash
bundle exec awfy ips Arrays "#map" --compare-with=main --compare-control
```

## Commit Range Analysis

Analyze performance across a range of commits:

```bash
bundle exec awfy ips Arrays "#map" --commit-range="HEAD~5..HEAD"
```

Skip specific commits:

```bash
bundle exec awfy ips Arrays "#map" --commit-range="HEAD~5..HEAD" --ignore-commits="abc123,def456"
```

## Custom Runners

### Parallel test execution: Forked Runner

Run tests in separate processes:

```bash
bundle exec awfy ips Arrays --runner=forked
```

Benefits:
- Process isolation
- Better memory cleanup
- Parallel execution

Use for CPU-bound tests and to utilize multiple cores.

### Parallel test execution: Thread Runner

Run tests in separate threads:

```bash
bundle exec awfy ips Arrays --runner=thread
```

Can be used with I/O-bound tests.

### Sequential test execution: Spawn Runner

Run tests in spawned processes:

```bash
bundle exec awfy ips Arrays --runner=spawn
```

Benefits:
- Complete isolation
- Fresh Ruby VM per test

### Sequential test execution: Immediate Runner

Run tests in the current process:

```bash
bundle exec awfy ips Arrays --runner=immediate
```

The default runner.

## Storage Backends

### SQLite Storage

Store results in SQLite database:

```bash
bundle exec awfy ips Arrays --storage-backend=sqlite
```

### JSON Storage

Store results as JSON files:

```bash
bundle exec awfy ips Arrays --storage-backend=json
```

### Memory Storage

Store results in memory only:

```bash
bundle exec awfy ips Arrays --storage-backend=memory
```

## Retention Policies

Each run, the results store is cleaned up based on the retention policy.

### Keep All

Keep all benchmark results:

```bash
bundle exec awfy ips Arrays --retention-policy=keep_all
```

### Date Based

Keep results for N days:

```bash
bundle exec awfy ips Arrays --retention-policy=date_based --retention-days=30
```

### Keep None

Delete results after running:

```bash
bundle exec awfy ips Arrays --retention-policy=keep_none
```

## Performance Assertions

**NOT IMPLEMENTED YET**

Add assertions to ensure performance meets requirements:

```ruby
Awfy.group "Arrays" do
  report "#map" do
    test "New Implementation" do
      array.map { |x| x * 2 }
    end

    # Assert performance requirements
    assert(
      # Memory assertions
      memory: {
        total_allocated_memory: { lt: 1000.0 },
        total_retained_memory: { eq: 0.0 }
      },
      # Speed assertions
      ips: {
        within: { times: 2.0, of: "Current Implementation" },
        minimum: 1_000_000
      }
    )
  end
end
```

## Custom Setup

Create helper methods in setup.rb:

```ruby
# benchmarks/setup.rb
module BenchmarkHelpers
  def setup_test_data(size)
    Array.new(size) { rand }
  end

  def warmup_cache
    GC.start
    sleep 0.1
  end
end

# Make helpers available in benchmarks
include BenchmarkHelpers
```

## Next Steps

- Check [Best Practices](best-practices.md) for optimization tips
- See [Configuration Guide](configuration.md) for all options
- Read [Command Reference](commands.md) for detailed commands