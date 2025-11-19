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

### Control Commit for Baseline Comparisons

When running benchmarks across a commit range, the traditional `control` block in your test definitions doesn't make sense because the control code itself changes with each checkout. Instead, you can designate a specific commit as the baseline using the `--control-commit` option.

By default, the **first commit in the range** is automatically used as the control:

```bash
# First commit (HEAD~5) is automatically used as baseline
bundle exec awfy ips start --commit-range="HEAD~5..HEAD" --runner=commit_range
```

All results from the control commit are marked with ✓ in the "Control" column, and all other commits' results are compared against the control commit's results.

#### Specifying a Custom Control Commit

You can specify a different commit as the baseline:

```bash
# Use a specific commit as the baseline
bundle exec awfy ips start \
  --commit-range="HEAD~10..HEAD" \
  --runner=commit_range \
  --control-commit=abc1234

# Use the middle commit in a range
bundle exec awfy ips start \
  --commit-range="v1.0.0..v2.0.0" \
  --runner=commit_range \
  --control-commit=v1.5.0
```

The control commit doesn't have to be in the commit range - you can compare against any commit:

```bash
# Compare feature branch commits against main
bundle exec awfy ips start \
  --commit-range="feature-branch~5..feature-branch" \
  --runner=commit_range \
  --control-commit=main
```

#### How Results Are Displayed

When using a control commit:
- Results from the control commit show ✓ in the "Control" column
- The summary displays: "Chosen test to compare against: [test name] from control commit abc1234"
- All comparisons (e.g., "2.0x faster", "0.5x slower") are relative to the control commit
- This applies to both IPS and memory benchmarks

**Example output:**
```
> Chosen test to compare against: Array#map/optimized from control commit 3e562740

┌─────────┬───────┬─────────┬─────────┬─────────┬──────────┬──────┬──────────┐
│ Times...│ Bra...│ Commit  │ Runtime │ Control │ Name     │  IPS │ vs Test  │
├─────────┼───────┼─────────┼─────────┼─────────┼──────────┼──────┼──────────┤
│ 2025-...│ HEAD  │ f8850900│ mri     │         │ optimized│ 176  │ 2.0x     │
│ 2025-...│ HEAD  │ 3e562740│ mri     │ ✓       │ optimized│  91  │ 1.0      │
│ 2025-...│ HEAD  │ 63b3faab│ mri     │         │ optimized│  46  │ -1.9x    │
└─────────┴───────┴─────────┴─────────┴─────────┴──────────┴──────┴──────────┘
```

In this example, commit 3e562740 is the control, and all other commits are compared against it.

### Benchmarking a Separate Repository

You can keep your benchmarks in one location and test a separate git repository. This is useful when:
- Your benchmarks are stable and don't need to be versioned with your code
- You want to benchmark a library from an external repository
- You maintain benchmarks separately from the code being tested

```bash
# Benchmark commits in a different repository
bundle exec awfy ips start \
  --commit-range="v1.0.0..v2.0.0" \
  --runner=commit_range \
  --target-repo-path=/path/to/your/app

# Your benchmarks stay in the current directory
# Git checkouts happen in /path/to/your/app
```

Example directory structure:
```
/home/user/my-benchmarks/
  benchmarks/
    setup.rb          # Add target repo to load path
    tests/
      performance.rb  # Your benchmark tests

/home/user/my-app/    # Separate git repository
  lib/
    my_code.rb        # Code being benchmarked
```

In your `setup.rb`, you can add the target repo to the load path:
```ruby
# benchmarks/setup.rb
target_repo = ENV['AWFY_TARGET_REPO'] || '/path/to/your/app'
$LOAD_PATH.unshift("#{target_repo}/lib")
```

Skip specific commits (if needed):

```bash
bundle exec awfy ips start --commit-range="HEAD~5..HEAD" --runner=commit_range --ignore-commits="abc123,def456"
```

### Commit Tracking in Results

All benchmark results automatically capture and store:
- **Commit Hash**: The full SHA of the commit where the benchmark was run
- **Commit Message**: The commit message for easy identification
- **Branch**: The git branch name

This information is displayed in summary tables (abbreviated to first 8 characters of the hash) and can be used to identify which code version produced each result. This is especially useful when reviewing historical results or comparing performance across commits.

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