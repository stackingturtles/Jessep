# Changelog

All notable changes to Jessep will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-07

### Added

- Initial release
- Menu bar icon with popover showing usage limits
- Display of session (5-hour), weekly, and Sonnet-only limits
- Progress bars matching Claude's UI design
- Usage prediction based on consumption rate
- Configurable warning threshold notifications
- Limit reached (100%) notifications
- Reset notifications when limits refresh
- Dynamic menu bar icon modes (static, percentage, colour)
- Launch at login support
- Automatic keychain integration with Claude Code
- Manual token entry fallback
- Offline support with cached data
- Dark theme matching Claude's design

### Security

- Tokens stored securely in macOS Keychain
- Hardened runtime enabled
- No data collection or external transmission

[Unreleased]: https://github.com/stackingturtles/jessep/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/stackingturtles/jessep/releases/tag/v1.0.0
