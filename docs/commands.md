# CLI Command Reference

This guide details all available Awfy CLI commands and their options.

```
$ exe/awfy
Commands:
  awfy config SUBCOMMAND      # Configuration-related commands (inspect, save)
  awfy flamegraph SUBCOMMAND  # Flamegraph-related commands (generate)
  awfy help [COMMAND]         # Describe available commands or one specific command
  awfy ips SUBCOMMAND         # IPS-related commands (start)
  awfy memory SUBCOMMAND      # Memory-related commands (start)
  awfy profile SUBCOMMAND     # Profile-related commands (start)
  awfy results SUBCOMMAND     # Results-related commands (list, show)
  awfy store SUBCOMMAND       # Store-related commands (clean)
  awfy suite SUBCOMMAND       # Suite-related commands (list, debug)
  awfy yjit-stats SUBCOMMAND  # YJIT stats-related commands (start)

Options:
  [--runtime=RUNTIME]                                                    # Run with and/or without YJIT enabled
                                                                         # Default: both
                                                                         # Possible values: both, yjit, mri
  [--compare-with-branch=COMPARE_WITH_BRANCH]                            # Name of branch to compare with results on current branch
  [--compare-control], [--no-compare-control], [--skip-compare-control]  # When comparing branches, also re-run all control blocks too
                                                                         # Default: false
  [--assert], [--no-assert], [--skip-assert]                             # Assert that the results are within a certain threshold coded in the tests
                                                                         # Default: false
  [--summary], [--no-summary], [--skip-summary]                          # Generate a summary of the results
                                                                         # Default: true
  [--summary-order=SUMMARY_ORDER]                                        # Sort order for summary tables: ascending, descending, or leaderboard (command specific, e.g. fastest to slowest for IPS)
                                                                         # Default: leader
                                                                         # Possible values: desc, asc, leader
  [--quiet], [--no-quiet], [--skip-quiet]                                # Silence output. Note if `summary` option is enabled the summaries will be displayed even if `quiet` enabled.
                                                                         # Default: false
  [--verbose=N]                                                          # Verbose output level (0=none, 1=basic, 2=detailed, 3=debug)
                                                                         # Default: 0
  [-v], [--no-v], [--skip-v]                                             # Shorthand for --verbose=1
                                                                         # Default: false
  [--runner=RUNNER]                                                      # Type of runner to use for benchmark execution
                                                                         # Default: immediate
                                                                         # Possible values: immediate, spawn, thread, forked, branch_comparison, commit_range
  [--test-warm-up=N]                                                     # Number of seconds to warmup the IPS benchmark
                                                                         # Default: 1.0
  [--test-time=N]                                                        # Number of seconds to run the IPS benchmark
                                                                         # Default: 3.0
  [--test-iterations=N]                                                  # Number of iterations to run the test
                                                                         # Default: 1000000
  [--setup-file-path=SETUP_FILE_PATH]                                    # Path to the setup file
                                                                         # Default: ./benchmarks/setup
  [--tests-path=TESTS_PATH]                                              # Path to the tests files
                                                                         # Default: ./benchmarks/tests
  [--storage-backend=STORAGE_BACKEND]                                    # Storage backend for benchmark results ('memory', 'json' or the default, 'sqlite')
                                                                         # Default: sqlite
  [--storage-name=STORAGE_NAME]                                          # Name for the storage repository (database name or directory)
                                                                         # Default: benchmark_history
  [--retention-policy=RETENTION_POLICY]                                  # Retention policy for benchmark results (keep or date)
                                                                         # Default: keep
  [--retention-days=N]                                                   # Number of days to keep results (only used with 'date' policy)
                                                                         # Default: 30
  [--list], [--no-list], [--skip-list]                                   # Display output in list format instead of table
                                                                         # Default: false
  [--color=COLOR]                                                        # Color output mode (auto, light, dark, off, or ansi for ANSI-only terminals)
                                                                         # Default: auto
                                                                         # Possible values: auto, light, dark, off, ansi
```

## Core Commands

### IPS Benchmarks

```bash
bundle exec awfy ips start [GROUP] [REPORT] [TEST]
```

Runs iterations per second benchmarks using benchmark-ips.

Or just:

```bash
bundle exec awfy ips
```

### Memory Profiling

```bash
bundle exec awfy memory start [GROUP] [REPORT] [TEST]
```

Profiles memory allocations using memory_profiler.

### CPU Profiling

```bash
bundle exec awfy profile start [GROUP] [REPORT] [TEST]
```

Profiles CPU usage using stackprof.

### Flamegraph Generation

```bash
bundle exec awfy flamegraph generate GROUP REPORT TEST
```

Generates flamegraphs using vernier.

### YJIT Statistics

```bash
bundle exec awfy yjitstats start [GROUP] [REPORT] [TEST]
```

Collects YJIT statistics for the benchmarks.

## Management Commands

### Suite Management

```bash
# List all tests
bundle exec awfy suite list [GROUP]

# Run suite without benchmarking (for debugging)
bundle exec awfy suite debug [GROUP]
```

### Configuration

```bash
# View current config
bundle exec awfy config inspect [LOCATION]

# Save config to file
bundle exec awfy config save [LOCATION]
```

Locations:
- `home` - ~/.awfy.json
- `suite` - ./benchmarks/.awfy.json
- `current` - ./.awfy.json

### Storage Management

```bash
# Clean up results based on current retention policy
bundle exec awfy store clean

# Clean up all results (use keep_none policy)
bundle exec awfy store clean --retention-policy=keep_none

# Clean up results older than 30 days
bundle exec awfy store clean --retention-policy=date --retention-days=30
```

Available retention policies:
- `keep` or `keep_all` - Keep all results (default)
- `date` or `date_based` - Keep results for specified days
- `none` or `keep_none` - Delete all results

### Results Browsing

View and analyze stored benchmark results without re-running benchmarks.

```bash
# List all stored benchmark results
bundle exec awfy results list

# List only IPS results
bundle exec awfy results list ips

# List only memory results
bundle exec awfy results list memory

# Show detailed results for a specific group
bundle exec awfy results show "Array Operations"

# Show results for a specific group and report
bundle exec awfy results show "Array Operations" "Array#map"

# Show only IPS results for a group/report
bundle exec awfy results show "Array Operations" "Array#map" ips

# Show only memory results for a group/report
bundle exec awfy results show "Array Operations" "Array#map" memory
```

The `results list` command shows:
- Result type (IPS, MEMORY)
- Group and report names
- Number of stored results
- Latest result timestamp
- Git branch

The `results show` command displays:
- Detailed summary tables for the specified group/report
- All historical results stored in the database
- Comparison against baseline results
- Same formatting as running benchmarks with `--summary`

## Common Options

### Runtime Options

```bash
--runtime=RUNTIME            # Run mode: both, yjit, or mri (default: both)
--test-warm-up=SECONDS      # Warmup time for IPS benchmarks (default: 1.0)
--test-time=SECONDS         # Test run time for IPS benchmarks (default: 3.0)
--test-iterations=NUMBER    # Number of iterations (default: 1000000)
```

### Comparison Options

```bash
--compare-with-branch=BRANCH     # Compare with another branch
--compare-control                # Re-run control blocks when comparing (default: false)
--commit-range=START..END        # Run benchmarks across commit range (requires --runner=commit_range)
--control-commit=COMMIT          # Commit to use as baseline for comparisons (defaults to first commit in range)
--target-repo-path=PATH          # Path to git repository for checkouts (defaults to current directory)
--assert                         # Enable assertions (default: false)
```

**Note on `--control-commit`:** When running benchmarks across a commit range, the first commit is automatically used as the baseline for comparisons. Use this option to specify a different commit as the baseline. All results are compared against this control commit. See [Control Commit for Baseline Comparisons](advanced-usage.md#control-commit-for-baseline-comparisons) for details.

**Note on `--target-repo-path`:** Allows you to keep benchmarks in one directory while testing commits from a different repository. This is useful for maintaining stable benchmarks separately from the code being tested.

### Output Options

```bash
--summary                    # Generate summary (default: true)
--summary-order=ORDER       # Sort order: desc, asc, leader (default: leader)
--quiet                     # Silence output
--verbose=LEVEL            # Output level: 0-3 (default: 0)
-v                        # Shorthand for --verbose=1
--list                     # List format output (default: false)
--color=MODE              # Color mode: auto, light, dark, off, ansi (default: auto)
```

### Runner Options

```bash
--runner=TYPE              # Runner type: immediate, forked, spawn, thread (default: immediate)
```

### Path Options

```bash
--setup-file-path=PATH     # Setup file path (default: ./benchmarks/setup)
--tests-path=PATH         # Test files path (default: ./benchmarks/tests)
```

### Storage Options

```bash
--storage-backend=TYPE     # Storage type: sqlite (default), json, memory
--storage-name=NAME       # Storage name (default: benchmark_history)
--retention-policy=POLICY # Retention: keep (default), date
--retention-days=DAYS    # Days to keep results (default: 30)
```

## Next Steps

- See [Configuration Guide](configuration.md) for detailed config options
- Check [Advanced Usage](advanced-usage.md) for complex scenarios
- Read [Best Practices](best-practices.md) for usage tips