# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Build/Install**: `bundle install`
- **Run Tests**: `bundle exec rake test`
- **Run Single Test**: `bundle exec ruby -Ilib:test test/test_file.rb -n test_method_name`
- **Lint/Format**: `bundle exec rake standard --fix`
- **Full Check**: `bundle exec rake` (runs tests and linting)
