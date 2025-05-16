# Configuration Guide

This guide explains how to configure Awfy using configuration files and CLI options.

## Configuration File Locations

Awfy supports configuration files in multiple locations, with the following precedence (from lowest to highest):

1. Home directory: `~/.awfy.json` - Global settings for all projects
2. Benchmark suite directory: `./benchmarks/.awfy.json` - Project-specific settings
3. Current directory: `./.awfy.json` - Local overrides for the current directory

Command line options always take the highest precedence and will override any settings from configuration files.

## Configuration Options

### Runtime Options

```json
{
  "runtime": "both",        // Run with and/or without YJIT ("both", "yjit", "mri")
  "test_time": 3.0,        // Seconds to run IPS benchmarks
  "test_iterations": 1000000, // Iterations to run tests
  "test_warm_up": 1.0      // Seconds to warmup IPS benchmarks
}
```

### Display Options

```json
{
  "verbose": 0,            // Verbose output level (0=none, 1=basic, 2=detailed, 3=debug)
  "quiet": false,          // Silence output (except summaries)
  "summary": true,         // Generate result summaries
  "summary_order": "leader", // Sort order ("desc", "asc", "leader")
  "list": false,          // Display in list instead of table format
  "color": "auto"         // Color mode ("auto", "light", "dark", "off", "ansi")
}
```

### Runner Options

```json
{
  "runner": "immediate",   // Runner type ("immediate", "forked", "spawn", "thread")
}
```

### Path Options

```json
{
  "setup_file_path": "./benchmarks/setup",   // Path to setup file
  "tests_path": "./benchmarks/tests",        // Path to test files
}
```

### Comparison Options

```json
{
  "compare_with_branch": null,    // Branch to compare with
  "compare_control": false,       // Re-run control blocks when comparing
  "assert": false                 // Enable assertions
}
```

### Storage Options

```json
{
  "storage_backend": "sqlite",    // Storage backend ("sqlite", "json", "memory")
  "storage_name": "benchmark_history", // Storage name
  "retention_policy": "keep",     // Retention policy ("keep", "date")
  "retention_days": 30           // Days to keep results (for date policy)
}
```

## Using the Config Command

### Inspecting Configuration

View the current effective configuration:

```bash
bundle exec awfy config inspect
```

View configuration from a specific location:

```bash
bundle exec awfy config inspect home    # ~/.awfy.json
bundle exec awfy config inspect suite   # ./benchmarks/.awfy.json
bundle exec awfy config inspect current # ./.awfy.json
```

### Saving Configuration

Save current settings to a configuration file:

```bash
# Save to current directory
bundle exec awfy config save --runtime=yjit --test-time=5

# Save to home directory
bundle exec awfy config save home --color=dark --verbose=2

# Save to benchmark suite directory
bundle exec awfy config save suite --storage-backend=json
```

## Verbosity Levels

The `verbose` option accepts numeric values:

- `0`: No verbose output (default)
- `1`: Basic progress information
- `2`: Detailed information including runtime data
- `3`: Full debug output

You can also use:
- `--quiet` to silence all output (except summaries)
- `-v` as shorthand for `--verbose=1`

Example:
```bash
bundle exec awfy ips start MyGroup --verbose=2
```

## Next Steps

- Read the [Command Reference](commands.md) for detailed CLI usage
- See [Advanced Usage](advanced-usage.md) for complex configurations
- Check [Best Practices](best-practices.md) for configuration tips