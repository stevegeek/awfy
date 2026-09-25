## [Unreleased]

### Added

- `awfy run <suite file>` measures each test of one suite file in-process and stores one `:measure` result per test under a label (`--label`, default the git branch or `unlabelled`). `--collectors` picks what to record, `--store` names the result store, and `--format json` / `--output` write the run document.
- `awfy compare --baseline <label> --against <label>` compares the latest results of two labels, per collector, as JSON, Markdown or a table. `--group` accepts a comma-separated list of groups.
- A collector API (`Awfy::Collector`, `Awfy::Collectors.register`) and the core collectors `timing`, `gc`, `rss`, `memory_profiler` and `vernier`. Heavy collectors (`memory_profiler`, `vernier`) get a pass of their own, so they do not distort the light ones.
- Suite DSL hooks `setup`, `before_each`, `after_each` and `isolate` (`:transaction`, `:none`, `:snapshot`) at group or report level, and test outcomes: a test block may return an object that responds to `awfy_outcome`, and `awfy compare` reports when the outcomes of two labels differ.
- `require "awfy/rails"` adds the Rails collectors `sql` (with N+1 candidates), `instantiation`, `cache` and `sidekiq`, `Awfy::Rails.boot!`, the `perform_job` and `request` helpers, and `isolate :transaction`, which rolls back each measured call. awfy does not depend on Rails.
- `assert` in a suite group or report declares performance bounds (`"<collector>.<metric>" => max_or_range`). `awfy run` checks them for every measured test, lists failures and exits 1.
- `awfy run` stores the run meta (Ruby, YJIT, awfy version, Rails env/version, jemalloc) with each measure result.
- `awfy compare` reports per-test `warnings` when isolation, runtime or run meta differ between the two labels, and lists collectors recorded under only one label in `collectors_missing`.
- The Rails `cache` collector counts compare-and-set calls (`cas`) and IdentityCache fetch, hit/miss, write, delete and hydration events (`identity_cache_*`). The keys appear only when those events occur; awfy does not depend on IdentityCache.

### Changed

- Results and stores carry a run label, and there is a new `:measure` result type.
- Git is opened lazily. A git error no longer aborts a command, and awfy works in a directory that is not a git repository.
- The `measure` and `compare` commands reject unknown options.
- `Awfy::Views::TimedProgressBar` uses a monotonic clock.
- The Rails SQL fingerprint now replaces Postgres `E'...'` escape strings (including backslash-escaped quotes) with `?` and removes `--` line comments; comment markers inside strings or quoted identifiers are left alone.

### Removed

- The global `--assert` option and the `assert` config key, which had no effect. Saved `.awfy.json` files that still contain `"assert"` load without error.

### Fixed

- Support benchmark-ips 2.15, whose `Stats::SD` constructor takes the measured time and iteration count. awfy works with benchmark-ips 2.14 and 2.15. Under 2.15, the IPS summary uses benchmark-ips's own mean (iterations per second over the whole run) instead of the mean of the per-cycle samples.
- `--compare-with-branch` works again: the branch comparison runner now implements the runner interface that the commands call.
- Branch and commit-range runs always restore the original branch or commit and your uncommitted changes, also when a run fails, and refuse to start in an unsafe git state (rebase, merge, cherry-pick, revert or bisect in progress, unmerged files, or no commit).
- The spawn runner now forwards all run options to the child process, supports group names with spaces, and runs `suite debug` jobs.
- The forked runner now reports a child that exits early or raises a non-StandardError exception as a failure instead of a success.
- `Suites::Report#without_control_tests` raised ArgumentError. `Awfy::Suite#tests?` answered whether any report existed, not whether any test existed.
- The memory job stored `retained_strings` as memory_profiler's raw array; it now stores a count, like `allocated_strings`.
- `--store` with an `.awfy.json` that sets another `storage_backend` no longer pairs the store name with the wrong backend.
- The repository is now clean under standardrb.

## [1.0.0] - ?

### Breaking Changes

- Awfy's CLI has changed, you will need to update yourself on the commands and switches

### Added

- Support for storage engines that let you persist results of runs, and then compare across them
- The ability to run benchmarks across multiple branches and commit ranges
- `--control-commit` option to designate a specific commit as the baseline for comparisons when using commit range runner (defaults to first commit in range)
- Multiple runner types are now supported
- `--target-repo-path` option to benchmark commits from a separate git repository
- `awfy results` commands for browsing stored benchmark results without re-running

### Fixed

- Commit range runner now properly handles root commits (commits with no parent)
- Commit range runner now works with all benchmark types (IPS, memory, YJIT stats) instead of being hardcoded to IPS only
- Fixed git stash handling to prevent "No stash entries found" errors
- Fixed VerbosityLevel type conversion when spawning subprocesses
- Updated table_tennis dependency to 0.0.7 to fix TTY detection issues
- All benchmark results now properly capture and display git commit hash, commit message, and branch information
- Fixed commit range runner to pass `--target-repo-path` to spawned processes for separate repository benchmarking


## [0.1.0] - 2024-10-28

- Initial release
