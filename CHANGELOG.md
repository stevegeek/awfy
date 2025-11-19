## [Unreleased]

## [1.0.0] - ?

### Breaking Changes

- Awfy's CLI has changed, you will need to update yourself on the commands and switches

### Added

- Support for storage engines that let you persist results of runs, and then compare across them
- The ability to run benchmarks across multiple branches and commit ranges
- Multiple runner types are now supported

### Fixed

- Commit range runner now properly handles root commits (commits with no parent)
- Fixed git stash handling to prevent "No stash entries found" errors
- Fixed VerbosityLevel type conversion when spawning subprocesses
- Updated table_tennis dependency to 0.0.7 to fix TTY detection issues


## [0.1.0] - 2024-10-28

- Initial release
