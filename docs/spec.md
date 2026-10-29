# Ner's Daily specification

The reference for the reminder logic and the data contract between the app and the sync service.
`Packages/NersCore` implements everything below and its tests pin it down.

## Fixed Vietnam time

- Every time is computed in `TimeZone(identifier: "Asia/Ho_Chi_Minh")` (UTC+7, no daylight saving), whatever the
  device time zone is. `TimeZone.current` is never used for scheduling.
- Times are stored and sent as absolute moments (`Date`, UTC ISO 8601 in JSON).
- Screens show Vietnam time, plus the local time when the device is in a different time zone.
- Alarms use `Alarm.Schedule.fixed(Date)` (AlarmKit) and notifications use `UNTimeIntervalNotificationTrigger` from an
  absolute moment. `Alarm.Schedule.relative` is never used because it follows the device time zone.
- The app schedules the next H days (14) ahead and refills on every launch, every "Taken", undo, settings change, and
  whenever the network comes back.

## Schedule and maximum gap

- The user sets a **main time** in Vietnam time (for example 21:00).
- **Maximum gap** between two consecutive doses: 24 hours by default.
- Next deadline = previous dose + maximum gap.
- Next reminder = min(the next main time in Vietnam time, the deadline). Taking a dose early pulls the next day
  earlier too. "Back to the main time" is available and warns when that dose would exceed the maximum gap.
- Reminder chain for each dose, all cancelled by "Taken":
  1. The main reminder.
  2. 3 repeats, 5 minutes apart.
  3. Then hourly.
  4. In the last 2 hours before the deadline: every 15 minutes.
  5. At the deadline: a ringing alarm regardless of the phone's mode.
  6. Past the deadline and still not taken: still ringing. 3 repeats 5 minutes apart, then every 15 minutes for the
     first 3 hours, then hourly until the end of the late window (12 hours after the deadline).
  Taking the pill at the main time every day puts the deadline on the next main time, so the part after the deadline
  is what keeps reminding until the pill is taken.
- Snooze rings again after 10 minutes and never moves the deadline.
- "Taken" can be undone for 10 minutes. Taken times can be edited in History.
- "Pause reminders for N days": no reminders and no misses during the pause. Afterwards the next dose starts from the
  main time.
- Everything must hold across time zone changes, midnight, early doses, late doses and skipped days.
- Invariant: two consecutive ringing alarms are never further apart than the maximum gap, and after a dose there is
  always a ringing alarm at or before its deadline.

## Statuses

| Status | Meaning | Color |
|---|---|---|
| Taken | Confirmed at or before the deadline, with a 15-minute tolerance so seconds or minutes do not count as late. | Green |
| Late | Taken after the deadline plus tolerance, but within the late window. The next dose counts from it. | Amber |
| Missed | No confirmation by the end of the late window. | Red |
| Made up | A missed dose for which an extra pill was taken later. | Blue |
| Paused | The dose fell inside a pause. | Grey |

Statuses always come with a label and an icon, never color alone.

## Make-up doses

- The Today screen lists missed doses from the last 7 days with a "Mark made up" button.
- Marking one stores a make-up record linked to that miss. It subtracts a pill when counting and does not change the
  schedule. Each miss can be made up once.
- A mistaken make-up is deleted in History and the pill is given back.
- While misses are not made up, every alert carries the line "N missed pills not made up".
- The app never advises whether or how to make up a pill. It points to the leaflet, a doctor or a pharmacist.

## Pills

- Counting is optional. Without it the app only reminds.
- With it, every "Taken" and every make-up subtracts a pill. "Add pills" adds to both the remaining count and the total.
- "Refill reminder": on or off, with a threshold (7 by default). At or below the threshold, every alert carries
  "N pills left, time to buy more".
- `daysTaken` = doses taken since pills were last entered or added (since the start when not counting).

## Sync (offline first)

- All reminders and calculations run on the device. When online, the app sends the latest snapshot; offline, it waits.
- The service never infers anything. It reports the latest data it received, with its update time.

### Data contract

`POST /v1/snapshot` with `Authorization: Bearer <token>` and a JSON body. The server keeps only the snapshot with the
newest `updatedAt` and answers older ones with 200 and `"stale": true`. Every response carries the current
`message` (set by the bot's `/msg`).

```json
{
  "schemaVersion": 1,
  "name": "Ner",
  "updatedAt": "2026-10-27T14:03:00Z",
  "lastTakenAt": "2026-10-27T14:03:00Z",
  "nextDueAt": "2026-10-28T14:00:00Z",
  "deadlineAt": "2026-10-28T14:03:00Z",
  "daysTaken": 12,
  "missedCount": 1,
  "lateCount": 0,
  "madeUpCount": 0,
  "pillsTotal": 28,
  "pillsRemaining": 16,
  "refillReminder": { "enabled": true, "daysBefore": 7 },
  "pausedUntil": null
}
```

- Times are UTC ISO 8601 without fractional seconds. `pillsTotal` and `pillsRemaining` are `null` when not counting.
  `lastTakenAt`, `pausedUntil` and `name` may be `null`. `name` is the user's name from the app, so the bot can use it.
- `missedCount` counts every miss, including made-up ones. `madeUpCount` counts the made-up ones.
- Older app versions do not send `lateCount` or `madeUpCount`; the server treats them as 0.
- `GET /v1/snapshot` (same token) returns the latest snapshot, or 404 when there is none.

## Telegram bot

- A dedicated bot that answers a single configured chat ID only.
- Messages on real changes: taken, undo, a new late or missed dose, a make-up, a pause, low pills.
- A 09:00 Vietnam time report every day: days taken, late, missed, made up, pills left, and the last sync.
  Snapshots older than 24 hours are flagged as not synced since then.
- `/check` returns the latest status, `/msg <text>` sets the message shown in the app, `/link` returns the connection code.
- Bot texts are Vietnamese by default, or English with `BOT_LANGUAGE=en`.
- All times are shown in Vietnam time. The bot token, API token and chat ID come from environment variables, never the repo.
