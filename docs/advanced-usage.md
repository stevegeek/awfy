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

Analyze performance across a range of commits. The commit range runner checks out each commit in the range and runs benchmarks on it.

```bash
# Run benchmarks across last 5 commits
bundle exec awfy ips start --commit-range="HEAD~5..HEAD" --runner=commit_range

# Run specific group across commits
bundle exec awfy ips start "Arrays" --commit-range="HEAD~5..HEAD" --runner=commit_range

# Use branch names or commit hashes
bundle exec awfy ips start --commit-range="main..feature-branch" --runner=commit_range
bundle exec awfy ips start --commit-range="abc123..def456" --runner=commit_range
```

**Note:** The commit range runner requires `--runner=commit_range` to be specified.

Skip specific commits (if needed):

```bash
bundle exec awfy ips start --commit-range="HEAD~5..HEAD" --runner=commit_range --ignore-commits="abc123,def456"
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

### Sequential test execution: Commit Range Runner

Run tests across multiple git commits:

```bash
bundle exec awfy ips start --commit-range="HEAD~5..HEAD" --runner=commit_range
```

Benefits:
- Compare performance across commits
- Track performance regressions
- Analyze performance trends

See [Commit Range Analysis](#commit-range-analysis) section above for more details.

### Sequential test execution: Branch Comparison Runner

Compare performance between git branches:

```bash
bundle exec awfy ips start --compare-with-branch=main --runner=branch_comparison
```

Benefits:
- Compare feature branch vs main
- Validate performance before merging
- Side-by-side branch comparison

## Storage Backends

### SQLite Storage

Store results in SQLite database (default):

```bash
bundle exec awfy ips start --storage-backend=sqlite --storage-name=my_benchmarks
```

### JSON Storage

Store results as JSON files:

```bash
bundle exec awfy ips start --storage-backend=json --storage-name=benchmark_data
```

### Memory Storage

Store results in memory only (not persisted):

```bash
bundle exec awfy ips start --storage-backend=memory
```

### Browsing Stored Results

View previously stored results without re-running benchmarks:

```bash
# List all stored results
bundle exec awfy results list

# Show detailed results for a specific group
bundle exec awfy results show "Array Operations"

# Show results for a specific report
bundle exec awfy results show "Array Operations" "Array#map"
```

See [Results Browsing](commands.md#results-browsing) in the command reference for more details.

## Retention Policies

Each run, the results store is cleaned up based on the retention policy. You can also manually clean using `awfy store clean`.

### Keep All (Default)

Keep all benchmark results indefinitely:

```bash
bundle exec awfy ips start --retention-policy=keep_all
# or use alias
bundle exec awfy ips start --retention-policy=keep
```

This is the default policy.

### Date Based

Keep results for N days, delete older ones:

```bash
bundle exec awfy ips start --retention-policy=date_based --retention-days=30
# or use alias
bundle exec awfy ips start --retention-policy=date --retention-days=30
```

### Keep None

Delete all results (useful for clearing storage or one-time runs):

```bash
bundle exec awfy ips start --retention-policy=keep_none
# or use alias
bundle exec awfy ips start --retention-policy=none
```

To manually clean all results from a store:

```bash
bundle exec awfy store clean --retention-policy=keep_none
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