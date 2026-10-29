# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.2] - 2026-10-29

### Added
- First launch asks for your name and, optionally, a partner's name and connection code. Both can be edited in Settings.
- The sync snapshot carries an optional `name`, so the bot addresses the right person.
- Bilingual README, contributing guide, security policy, issue and pull request templates.

### Changed
- No hardcoded names in the app. Without a partner name, texts say "your partner".
- Disabled buttons now look disabled, and non-editable History rows are no longer greyed out.

## [0.1.1] - 2026-10-29

### Added
- Vietnamese and English, chosen on first launch and changeable in Settings.
- Make-up doses: mark a missed pill as made up from the Today screen. Alerts mention outstanding missed pills.

### Removed
- The signature expiry warning. SideStore handles refreshing.

## [0.1.0] - 2026-10-29

### Added
- Reminders on Vietnam time with AlarmKit alarms that ring on silent and in Focus, or notifications that follow the phone's mode.
- A reminder chain up to the 24-hour deadline, which keeps ringing for 12 hours after it. Late and missed doses are tracked.
- Undo, editing the taken time, pausing reminders, pill counting and a refill reminder.
- History calendar, a lock screen countdown while snoozed, and light and dark mode.
- Optional sync to a self-hosted service with a private Telegram bot.
- Release builds and a SideStore source published from GitHub Actions.

[Unreleased]: https://github.com/finnwasabi/ners-daily/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/finnwasabi/ners-daily/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/finnwasabi/ners-daily/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/finnwasabi/ners-daily/releases/tag/v0.1.0
