# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.4] - 2026-10-29

### Fixed
- History stats stay level: the first label is shorter ("taken") and numbers align at the top when a label wraps.

## [0.1.3] - 2026-10-29

### Added
- "Back to the main time" on the Today screen after an early dose pulled the schedule earlier, with a warning when the next dose would exceed 24 hours.
- The bot speaks English with `BOT_LANGUAGE=en`.
- A randomized test that runs 12,000 user actions against the scheduling invariants.

### Fixed
- Changing the pill time in Settings now takes effect. Moving it earlier applies from the next day; moving it later asks for confirmation because the gap exceeds 24 hours. Before, the 24-hour rule kept reminding at the old time.
- Layouts no longer overflow at the largest accessibility text sizes; the first-launch screens scroll when needed.
- Long names wrap cleanly and are capped at 40 characters.
- An overdue dose from yesterday shows as late in the week strip instead of upcoming, and its time says "yesterday".

### Changed
- Code comments, the specification and the server docs are in English.

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

[Unreleased]: https://github.com/finnwasabi/ners-daily/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/finnwasabi/ners-daily/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/finnwasabi/ners-daily/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/finnwasabi/ners-daily/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/finnwasabi/ners-daily/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/finnwasabi/ners-daily/releases/tag/v0.1.0
