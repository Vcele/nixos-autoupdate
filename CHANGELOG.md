# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Complete flake-based module structure for easy integration
- Support for local (non-git) flake updates via `localFlake` option
- Laptop wake-up functionality using RTC wake alarms
  - `wakeup.enable` option to enable wake-from-sleep
  - Wake-up time is controlled by the `schedule` option
  - `wakeup.autoSuspendAfter` to auto-suspend after update if no users logged in
- AC power detection with `onlyOnACPower` option
- Desktop notification system for both successful and failed updates
- Comprehensive documentation (README, QUICKSTART, TESTING, MIGRATION)
- Automated test suite
- Example configurations for various scenarios

### Changed
- Converted from standalone module to proper NixOS flake
- Made SSH/sops configuration optional (only required for git+ssh repositories)
- Simplified wake-up: uses `schedule` for both timer and wake-up time

### Deprecated
- `repository` option (use `flake` instead for consistency)
