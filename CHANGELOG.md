## [Unreleased]

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
