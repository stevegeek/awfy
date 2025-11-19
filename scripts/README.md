# Scripts

This directory contains utility scripts for awfy development and testing.

## Test Scripts

### test_commit_range.rb

Tests the commit range feature by creating a temporary git repository with benchmark files and running benchmarks across multiple commits.

```bash
bundle exec ruby scripts/test_commit_range.rb
```

This script tests two scenarios:

**Scenario 1: Benchmarks and code in same repository**
1. Creates a temporary git repository
2. Sets up benchmark files with proper structure
3. Creates multiple commits with incremental changes
4. Tests the commit range runner across all commits

**Scenario 2: Benchmarks and code in separate repositories**
1. Creates two separate directories (benchmarks and code repo)
2. Sets up benchmarks in one directory
3. Creates commits in the separate code repository
4. Tests the commit range runner with `--target-repo-path`

Both scenarios clean up automatically after completion.

Use this to verify the commit range feature works correctly after making changes, including the ability to benchmark a separate repository.

## Demo Generation Scripts

### Files

- `cast_generator.rb` - Core library for generating asciinema cast files
- `generate_demo.rb` - Main script that defines and generates the demo
- `agg.toml` - Configuration for agg (GIF generator)

## Usage

### Generate Demo Cast File

```bash
bundle exec ruby scripts/generate_demo.rb
```

This will:
1. Execute the demo commands
2. Capture real output from awfy
3. Generate `demo.cast` file
4. Optionally generate `demo.gif` if agg is installed

### View the Demo

```bash
asciinema play demo.cast
```

### Upload to asciinema.org

```bash
asciinema upload demo.cast
```

Then update the README with the badge:
```markdown
[![asciicast](https://asciinema.org/a/XXXXX.svg)](https://asciinema.org/a/XXXXX)
```

### Generate GIF

Install [agg](https://github.com/asciinema/agg):

```bash
# On macOS
brew install agg

# Or download from releases
# https://github.com/asciinema/agg/releases
```

Then run:
```bash
agg demo.cast demo.gif
```

Or with custom settings:
```bash
agg --theme monokai --font-family "JetBrains Mono" demo.cast demo.gif
```

## Customizing the Demo

Edit `generate_demo.rb` to add, remove, or modify commands:

```ruby
cast = record_cast(
  width: 120,
  height: 30,
  title: "My Demo"
) do
  comment "This is a comment that appears but doesn't execute"

  command "bundle exec awfy suite list", pause_after: 2.0

  pause 1.0  # Add pauses between commands

  command "bundle exec awfy ips start MyGroup MyReport",
    type_speed: 20,      # Simulate typing (chars per second)
    pause_before: 0.5,   # Pause before typing
    pause_after: 3.0     # Pause after command completes
end
```

## Cast Generator API

The `CastGenerator` class provides:

- `command(cmd, type_speed: nil, pause_before: 0, pause_after: 1.5)` - Execute a command
- `pause(duration)` - Add a pause without executing anything
- `comment(text, pause_after: 0.5)` - Add a comment line
- `generate(output_file)` - Write the cast file

## Troubleshooting

### Commands run but output is missing
Make sure commands output to stdout and handle terminal colors properly.

### Timing seems off
Adjust `idle_time_limit` in `record_cast` to control how asciinema handles pauses.

### GIF is too large
Customize agg settings in `agg.toml` or use command-line options:
- `--fps-cap` - Limit framerate (default: 30)
- `--speed` - Playback speed multiplier
- `--cols`, `--rows` - Terminal dimensions
