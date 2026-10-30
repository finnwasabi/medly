# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.3] - 2026-10-30

### Fixed
- The whole tab bar flashed on every tab change: each screen carried its own copy of the bar. There is one bar again, and the highlight slides under the labels instead of fading over them. The same fix keeps the medication editor and the segmented choices on a single sheet and a single highlight.

## [0.3.2] - 2026-10-30

### Fixed
- Add medication sometimes opened nothing on the Meds tab, and from then on no screen could open the editor until the app was restarted. Adding and editing now share one editor sheet at the root of the app.

### Changed
- Smoother navigation: the tab bar highlight slides between tabs, the tapped icon bounces and the new screen fades in. Segmented choices slide too, stepper numbers roll, and medication cards animate when added, removed, taken or skipped. Reduce Motion turns the movement off.

## [0.3.1] - 2026-10-30

### Changed
- The app is now called Pillot, and the repository is `finnwasabi/pillot`. Installed copies update in place and keep their data, and the old SideStore source addresses keep working through GitHub's redirect.
- Backups are saved as `Pillot-backup-YYYY-MM-DD.json`. Backups saved by Medly still restore.
- The Telegram bot is named Pillot.

## [0.3.0] - 2026-10-30

### Added
- Backup and restore: save a file with every medication, its history and your preferences wherever you like (iCloud Drive, Google Drive, a chat), and restore it after a confirmation. Settings reminds you when there is no recent backup.
- Skip this dose: stops the reminders for one dose without counting it as missed or using a pill. It can be undone for 10 minutes on Today, or deleted in History.
- Days off in a cycle, such as 21 days on and 7 off: nothing rings and nothing counts as missed on days off.
- Home screen and lock screen widgets with the next doses.
- An App Shortcut, "I took my meds", for Siri, Shortcuts and Spotlight.
- A first launch step to pick light, dark or the phone's appearance, before the language.
- Bot: a nudge when a deadline passes with no dose reported, skipped doses, and the bot is named Medly.

### Changed
- The app is now called Medly, and the repository is `finnwasabi/medly`. Installed copies update in place and keep their data.
- The data file moves into an App Group shared with the widget.

## [0.2.1] - 2026-10-29

### Added
- Appearance in Settings: follow the phone, light or dark.
- Pills per pack for each medication. "Add a pack" adds that many, and starting to count suggests one pack.
- Number steppers repeat while held, and pill counts can be typed. The remaining count can be corrected down as well as up.

### Changed
- Outlines are slightly thinner, and small elements (chips, pills, calendar days) use a thinner line than cards.
- The maximum gap row shows its range, and the footer explains why it cannot be shorter than the time between doses.
- Pausing a medication also stops its ringing or snoozed alarm.

### Fixed
- Tapping the snooze stepper crashed the app.
- The end of every screen stayed hidden under the tab bar on 6.1 inch iPhones.
- A medication deleted while its editor was open came back on Save.
- Server: calls to Telegram no longer fail about half the time on hosts without IPv6, and setting the command menu is retried.

## [0.2.0] - 2026-10-29

### Added
- A Meds tab: keep several medications, each with its own name, color, icon, dose time, doses per day (1, 2, 3, 4 or 6), maximum gap, pill count, refill reminder and pause.
- Reminders name the medication. Medications due at the same moment share one alarm, and one "Taken" covers them all; a "Took all" button appears on Today when several are due.
- The maximum gap between doses can be changed, from one period up to one and a half (24 to 36 hours for a daily medication).
- Snooze length in Settings, 1 to 15 minutes. Snooze as often as needed; only "Taken" stops an alarm.
- History filters by medication.
- Bot: `/start`, `/help`, `/clearmsg`, a Copy button on `/link`, a Refresh button on `/check` and the morning report, messages when a medication is added or removed, and a command menu and profile descriptions.

### Changed
- A brand new look: cute neubrutalism with pastel fills, ink outlines and hard shadows, a custom tab bar and a new icon.
- Snooze defaults to 9 minutes, like the iPhone Clock app.
- A dose that is due but not past its deadline shows as "Due now" instead of "Late".
- Taking one medication no longer stops another medication's ringing or snoozed alarm.
- Snapshots are version 2 with one entry per medication. The server still accepts version 1 from older apps.
- Bot texts are English only, with HTML formatting. `BOT_LANGUAGE` is gone.

## [0.1.7] - 2026-10-29

### Fixed
- A late dose taken more than 12 hours after its main time now shows on the day of the dose it was late for, in the week strip and the calendar.
- Changing the main time no longer unlinks earlier make-ups, so a made-up miss does not come back as "not made up".

### Changed
- The release workflow refuses a tag that is not the tip of `main`, misses commits from `develop` or has no changelog section.

## [0.1.6] - 2026-10-29

### Fixed
- 0.1.4 and 0.1.5 were built from an outdated commit and did not contain their fixes. This release ships both: the level History stats and the "no data" days in the week strip.

## [0.1.5] - 2026-10-29

### Fixed
- The week strip no longer shows past days as late on a fresh install. Days before the first dose show "No data"; only an overdue dose shows as late.

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

[Unreleased]: https://github.com/finnwasabi/pillot/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/finnwasabi/pillot/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/finnwasabi/pillot/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/finnwasabi/pillot/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/finnwasabi/pillot/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/finnwasabi/pillot/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/finnwasabi/pillot/compare/v0.1.7...v0.2.0
[0.1.7]: https://github.com/finnwasabi/pillot/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/finnwasabi/pillot/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/finnwasabi/pillot/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/finnwasabi/pillot/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/finnwasabi/pillot/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/finnwasabi/pillot/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/finnwasabi/pillot/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/finnwasabi/pillot/releases/tag/v0.1.0
