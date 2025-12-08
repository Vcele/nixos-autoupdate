# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete flake-based module structure for easy integration
- Support for local (non-git) flake updates via `localFlake` option
- Laptop wake-up functionality using RTC wake alarms
  - `wakeup.enable` option to enable wake-from-sleep
  - `wakeup.wakeupTime` to specify wake time (HH:MM format)
  - `wakeup.autoSuspendAfter` to auto-suspend after update if no users logged in
- AC power detection with `onlyOnACPower` option
  - Prevents updates when running on battery power
  - Uses multiple detection methods for compatibility
- Desktop notification system
  - `notification.enable` to enable notifications
  - `notification.urgency` to set notification urgency level
  - `notification.timeout` to control notification duration
  - Shows notifications on next login if update occurred while logged out
- Comprehensive documentation
  - Updated README with all new features
  - Example configurations for different scenarios
  - TESTING.md with detailed testing instructions
- Automated test suite (`test/run-tests.sh`)
- Example configurations for:
  - Local flake setup
  - Laptop configuration with all features
  - Desktop with git repository
  - Server configuration

### Changed
- Converted from standalone module to proper NixOS flake
- Made SSH/sops configuration optional (only required for git+ssh repositories)
- Improved error messages and assertions
- Enhanced documentation with comprehensive examples

### Deprecated
- `repository` option (use `flake` instead for consistency)

## [1.0.0] - Initial Release

### Added
- Basic automatic update functionality from git repositories
- SSH key management via sops-nix
- Configurable update schedule
- Low-priority CPU and I/O scheduling
- Automatic retry on failure
- Pre-update SSH connection test
- Git dirty check to prevent updates with uncommitted changes
- Comprehensive configuration options for scheduling and resource management
