import Foundation

/// A dose that is pending or upcoming.
public struct Dose: Equatable, Sendable {
    /// The main time (Vietnam time) this dose belongs to.
    public var slotAt: Date
    /// The main reminder time.
    public var dueAt: Date
    /// The deadline, where a ringing alarm fires.
    public var deadlineAt: Date
    /// Taken after the deadline but before this counts as late; after this it counts as missed.
    public var lateUntil: Date
    /// True when this dose was moved "back to the main time" and exceeds the maximum gap.
    public var exceedsMaxInterval: Bool
    /// The anchor for the deadline: the previous dose, or a virtual one after a miss or a pause.
    var anchor: Date
}

public enum ReminderKind: String, Codable, Sendable {
    case main, `repeat`, hourly, final, deadline
    /// After the deadline: keeps ringing until taken or until the late window ends.
    case overdue
}

public struct ReminderEvent: Equatable, Sendable {
    public var date: Date
    public var kind: ReminderKind
    /// A ringing alarm regardless of the phone's mode. True from the deadline on.
    public var requiresSound: Bool
    public var dueAt: Date
    public var deadlineAt: Date
}

/// Preview of "back to the main time".
public struct ResetPreview: Equatable, Sendable {
    public var dueAt: Date
    public var deadlineAt: Date
    /// True when that dose would be further than the maximum gap from the previous one; the app must warn.
    public var exceedsMaxInterval: Bool
}

/// Computes the schedule from settings and history. Never reads the clock; `now` is always a parameter.
public struct Planner: Sendable {
    public var settings: ReminderSettings
    /// Dose history: taken doses (`.taken`) and make-ups (`.madeUp`).
    public var history: [DoseRecord]

    public init(settings: ReminderSettings = ReminderSettings(), history: [DoseRecord] = []) {
        self.settings = settings
        self.history = history
    }

    // MARK: Queries

    /// The dose pending at `now`.
    public func currentDose(now: Date) -> Dose { walk(now: now).dose }

    /// The next reminder time.
    public func nextReminder(now: Date) -> Date { currentDose(now: now).dueAt }

    public func missedCount(now: Date) -> Int { walk(now: now).missed }

    /// Doses taken after the deadline but within the late window.
    public func lateCount(now: Date) -> Int { walk(now: now).late }

    /// Doses taken since pills were last entered or added, or since the start when not counting. With one dose a day
    /// this is the number of days.
    public func daysTaken(now: Date) -> Int {
        let since = settings.pills?.countingSince ?? .distantPast
        return takes(upTo: now).filter { $0.takenAt! >= since }.count
    }

    public func lastTaken(now: Date) -> DoseRecord? { takes(upTo: now).last }

    /// Full history for display: doses (on time or late), misses, make-ups and paused slots.
    public func timeline(now: Date) -> [DoseRecord] { resolved(now: now).records }

    /// Misses that were made up. `missedCount` still includes them.
    public func madeUpCount(now: Date) -> Int { resolved(now: now).matched }

    /// Misses not made up within the last `days` days, newest first.
    public func outstandingMissed(now: Date, days: Int = 7) -> [DoseRecord] {
        let since = now.addingTimeInterval(-TimeInterval(days) * VietnamClock.day)
        return timeline(now: now).filter { $0.status == .missed && $0.scheduledAt >= since }.reversed()
    }

    /// Matches each make-up to the miss it covers. A make-up that no longer matches a miss (for example after an edit
    /// removed the miss) stays in history so it can be deleted, but does not count as made up.
    private func resolved(now: Date) -> (records: [DoseRecord], matched: Int) {
        var records = walk(now: now).records
        var unused = history.filter { $0.status == .madeUp && ($0.takenAt ?? .distantFuture) <= now }
        var matched = 0
        for i in records.indices where records[i].status == .missed {
            // The nearest make-up within half a period, not an exact match: changing the main time recomputes the
            // reminder time of past misses, and the make-up must stay linked to its miss.
            let missedAt = records[i].scheduledAt
            let distance = { (record: DoseRecord) in record.makesUpFor.map { abs($0.timeIntervalSince(missedAt)) } ?? .infinity }
            guard let k = unused.indices.min(by: { distance(unused[$0]) < distance(unused[$1]) }),
                  distance(unused[k]) < halfPeriod else { continue }
            records[i] = unused.remove(at: k)
            records[i].scheduledAt = missedAt
            matched += 1
        }
        records += unused
        records.sort { $0.scheduledAt < $1.scheduledAt }
        return (records, matched)
    }

    /// Status of each past Vietnam day (keyed by the start of the day), for the calendar and the week strip.
    /// A day with several records takes the worst status: missed, made up, late, taken, paused.
    public func dayStatuses(now: Date) -> [Date: DoseStatus] {
        func rank(_ status: DoseStatus) -> Int {
            switch status {
            case .missed: 4
            case .madeUp: 3
            case .late: 2
            case .taken: 1
            case .paused: 0
            }
        }
        var result: [Date: DoseStatus] = [:]
        for record in timeline(now: now) {
            // Each record belongs to its nearest main time, the same rule that picks the next dose after a take.
            // A make-up belongs to the day of the miss it covers and a late dose to the day of the dose it was late for,
            // not the day they were taken.
            let moment = record.status == .madeUp || record.status == .late ? record.scheduledAt : (record.takenAt ?? record.scheduledAt)
            let slot = firstSlot(after: moment.addingTimeInterval(-halfPeriod))
            let day = VietnamClock.calendar.startOfDay(for: slot)
            if let existing = result[day], rank(existing) >= rank(record.status) { continue }
            result[day] = record.status
        }
        return result
    }

    /// When a snooze rings again. Never past the deadline, and the deadline stays put.
    public func snoozeUntil(now: Date) -> Date {
        let wake = now.addingTimeInterval(max(60, settings.snoozeInterval))
        let deadline = currentDose(now: now).deadlineAt
        return now < deadline ? min(wake, deadline) : wake
    }

    /// Reminder events for the next `horizonDays` days, sorted and without duplicate times.
    /// Doses after the pending one are planned as if never confirmed; "Taken" makes the app recompute.
    public func events(now: Date, horizonDays: Int = 14) -> [ReminderEvent] {
        let end = now.addingTimeInterval(TimeInterval(horizonDays) * VietnamClock.day)
        var dose = currentDose(now: now)
        var byDate: [Date: ReminderEvent] = [:]
        while dose.dueAt <= end {
            if let pause = overlappingPause(dose, startedBy: .distantFuture) {
                dose = doseAfterPause(pause.end)
                continue
            }
            for event in chain(for: dose) where event.date > now && event.date <= end {
                if settings.pauses.contains(where: { $0.contains(event.date) }) { continue }
                if let existing = byDate[event.date], priority(existing.kind) >= priority(event.kind) { continue }
                byDate[event.date] = event
            }
            dose = doseAfterMiss(dose)
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    /// Previews "back to the main time" for the next dose. `nil` when the pending dose does not follow directly from a take
    /// (after a miss or a pause the next dose already starts from the main time).
    public func resetPreview(now: Date) -> ResetPreview? {
        let state = walk(now: now)
        guard state.followsTake, var take = takes(upTo: now).last else { return nil }
        take.nextAtMainTime = true
        let dose = doseAfterTake(take)
        return ResetPreview(dueAt: dose.dueAt, deadlineAt: dose.deadlineAt, exceedsMaxInterval: dose.exceedsMaxInterval)
    }

    // MARK: Actions

    /// "Taken" at `now`. Subtracts a pill when counting.
    @discardableResult
    public mutating func markTaken(at now: Date) -> DoseRecord {
        let consumed = settings.pills?.consume() ?? false
        let record = DoseRecord(scheduledAt: currentDose(now: now).dueAt, takenAt: now, status: .taken, consumedPill: consumed)
        history.append(record)
        return record
    }

    /// Undoes the latest "Taken" if still within `undoWindow`.
    @discardableResult
    public mutating func undoLastTaken(now: Date) -> Bool {
        guard let last = takes(upTo: now).last, now.timeIntervalSince(last.takenAt!) <= settings.undoWindow,
              let index = history.firstIndex(where: { $0.id == last.id }) else { return false }
        history.remove(at: index)
        if last.consumedPill { settings.pills?.restore() }
        return true
    }

    /// Edits a taken time in history.
    public mutating func editTakenTime(id: UUID, to date: Date) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].takenAt = date
    }

    /// Makes up the miss with this `scheduledAt`. Subtracts a pill when counting. Does not change the schedule.
    /// Returns `nil` when there is no such miss or it was already made up.
    @discardableResult
    public mutating func markMadeUp(missedAt scheduledAt: Date, at now: Date) -> DoseRecord? {
        guard timeline(now: now).contains(where: { $0.status == .missed && $0.scheduledAt == scheduledAt }) else { return nil }
        let consumed = settings.pills?.consume() ?? false
        let record = DoseRecord(scheduledAt: scheduledAt, takenAt: now, status: .madeUp, consumedPill: consumed, makesUpFor: scheduledAt)
        history.append(record)
        return record
    }

    /// Deletes a history record (for a mistaken make-up) and gives the pill back if one was taken.
    public mutating func removeRecord(id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        if history.remove(at: index).consumedPill { settings.pills?.restore() }
    }

    /// "Back to the main time" for the next dose. Returns the preview so the app can warn about the maximum gap.
    @discardableResult
    public mutating func resetToMainTime(now: Date) -> ResetPreview? {
        guard let preview = resetPreview(now: now), let last = takes(upTo: now).last,
              let index = history.firstIndex(where: { $0.id == last.id }) else { return nil }
        history[index].nextAtMainTime = true
        return preview
    }

    /// Changes the main time and realigns the pending dose to it. Without this, the 24 h rule would keep reminding at
    /// the old time forever. Use `previewMainTimeChange` first to warn when the next dose would exceed the maximum gap.
    public mutating func changeMainTime(hour: Int, minute: Int, now: Date) {
        changeSchedule(hour: hour, minute: minute, dosesPerDay: settings.dosesPerDay, now: now)
    }

    /// Changes the main time and the doses per day, and realigns the pending dose. A new number of doses per day also
    /// moves the maximum gap into the new allowed range.
    public mutating func changeSchedule(hour: Int, minute: Int, dosesPerDay: Int, now: Date) {
        settings.mainHour = hour
        settings.mainMinute = minute
        if dosesPerDay != settings.dosesPerDay, ReminderSettings.allowedDosesPerDay.contains(dosesPerDay) {
            settings.dosesPerDay = dosesPerDay
            settings.maxInterval = settings.period
        }
        guard walk(now: now).followsTake, let last = takes(upTo: now).last,
              let index = history.firstIndex(where: { $0.id == last.id }) else { return }
        history[index].nextAtMainTime = true
    }

    /// What the pending dose would become after `changeMainTime`.
    public func previewMainTimeChange(hour: Int, minute: Int, now: Date) -> ResetPreview {
        previewScheduleChange(hour: hour, minute: minute, dosesPerDay: settings.dosesPerDay, now: now)
    }

    /// What the pending dose would become after `changeSchedule`.
    public func previewScheduleChange(hour: Int, minute: Int, dosesPerDay: Int, now: Date) -> ResetPreview {
        var copy = self
        copy.changeSchedule(hour: hour, minute: minute, dosesPerDay: dosesPerDay, now: now)
        let dose = copy.currentDose(now: now)
        return ResetPreview(dueAt: dose.dueAt, deadlineAt: dose.deadlineAt, exceedsMaxInterval: dose.exceedsMaxInterval)
    }

    /// "Pause reminders for N days" starting at `now`.
    public mutating func pause(days: Int, now: Date) {
        guard days > 0 else { return }
        settings.pauses.append(PausePeriod(start: now, end: now.addingTimeInterval(TimeInterval(days) * VietnamClock.day)))
    }

    /// Ends any pause at `now`.
    public mutating func resume(now: Date) {
        for i in settings.pauses.indices where settings.pauses[i].contains(now) {
            settings.pauses[i].end = now
        }
    }

    /// Adds pills, or starts counting if not counting yet.
    public mutating func addPills(_ count: Int, now: Date) {
        if settings.pills == nil {
            settings.pills = PillCounter(count: count, at: now)
        } else {
            settings.pills?.add(count, at: now)
        }
    }

    // MARK: Scheduling

    private struct WalkState {
        var dose: Dose
        var missed = 0
        var late = 0
        var records: [DoseRecord] = []
        /// The pending dose follows directly from the last take, with no miss or pause in between.
        var followsTake = false
    }

    private func takes(upTo now: Date) -> [DoseRecord] {
        history
            .filter { $0.status == .taken && ($0.takenAt.map { $0 <= now } ?? false) }
            .sorted { $0.takenAt! < $1.takenAt! }
    }

    /// Walks the takes up to `now`, counting misses, and returns the pending dose.
    private func walk(now: Date) -> WalkState {
        let taken = takes(upTo: now)
        guard let first = taken.first else {
            // No history yet: the first dose is the next main time after `now`.
            var state = WalkState(dose: doseFromMainTime(firstSlot(after: now)))
            advance(&state, before: now)
            return state
        }
        var state = WalkState(dose: doseAfterTake(first), records: [first], followsTake: true)
        for take in taken.dropFirst() {
            advance(&state, before: take.takenAt!)
            if take.takenAt! > state.dose.deadlineAt.addingTimeInterval(max(0, settings.lateTolerance)) {
                var record = take
                record.status = .late
                record.scheduledAt = state.dose.dueAt
                state.records.append(record)
                state.late += 1
            } else {
                state.records.append(take)
            }
            state.dose = doseAfterTake(take)
            state.followsTake = true
        }
        advance(&state, before: now)
        return state
    }

    /// Skips doses inside pauses and counts doses whose late window ended before `t`.
    private func advance(_ state: inout WalkState, before t: Date) {
        while true {
            if let pause = overlappingPause(state.dose, startedBy: t) {
                state.records.append(DoseRecord(scheduledAt: state.dose.dueAt, takenAt: nil, status: .paused))
                state.dose = doseAfterPause(pause.end)
                state.followsTake = false
            } else if state.dose.lateUntil < t {
                state.missed += 1
                state.records.append(DoseRecord(scheduledAt: state.dose.dueAt, takenAt: nil, status: .missed))
                state.dose = doseAfterMiss(state.dose)
                state.followsTake = false
            } else {
                return
            }
        }
    }

    private func overlappingPause(_ dose: Dose, startedBy t: Date) -> PausePeriod? {
        settings.pauses.first { $0.start <= t && $0.start < $0.end && dose.dueAt < $0.end && dose.lateUntil >= $0.start }
    }

    private var maxInterval: TimeInterval { max(60, settings.maxInterval) }
    private var period: TimeInterval { settings.period }
    private var halfPeriod: TimeInterval { settings.period / 2 }
    /// Never longer than half a period, so with several doses a day a dose turns missed before the one after next is due.
    private var lateWindow: TimeInterval { min(max(0, settings.lateWindow), halfPeriod) }
    private var overdueBurst: TimeInterval { min(max(0, settings.overdueBurst), lateWindow) }

    /// The first scheduled dose time strictly after `date`. Doses repeat every `period` from the main time; 24 h is a
    /// multiple of the period and Vietnam has no daylight saving, so this is plain arithmetic.
    func firstSlot(after date: Date) -> Date {
        let base = VietnamClock.mainTime(onDayOf: date, hour: settings.mainHour, minute: settings.mainMinute)
        return base.addingTimeInterval((floor(date.timeIntervalSince(base) / period) + 1) * period)
    }

    /// The first scheduled dose time at or after `date`.
    func firstSlot(atOrAfter date: Date) -> Date {
        let base = VietnamClock.mainTime(onDayOf: date, hour: settings.mainHour, minute: settings.mainMinute)
        return base.addingTimeInterval(ceil(date.timeIntervalSince(base) / period) * period)
    }

    private func dose(slot: Date, anchor: Date) -> Dose {
        let deadline = anchor.addingTimeInterval(maxInterval)
        return Dose(slotAt: slot, dueAt: min(slot, deadline), deadlineAt: deadline, lateUntil: deadline.addingTimeInterval(lateWindow),
                    exceedsMaxInterval: false, anchor: anchor)
    }

    /// After a take at T: the next dose belongs to the first dose time after T + half a period, so the take at T
    /// counts for its nearest dose time. Reminder = min(that time, T + maximum gap).
    private func doseAfterTake(_ take: DoseRecord) -> Dose {
        let t = take.takenAt!
        let slot = firstSlot(after: t.addingTimeInterval(halfPeriod))
        guard take.nextAtMainTime else { return dose(slot: slot, anchor: t) }
        // Realigned (back to the main time, or the schedule changed): the next dose time at least a quarter period after
        // the take, so moving the time earlier takes effect on the next dose instead of being swallowed by the half rule.
        let aligned = firstSlot(after: t.addingTimeInterval(period / 4))
        let normalDeadline = t.addingTimeInterval(maxInterval)
        let deadline = max(aligned, normalDeadline)
        return Dose(slotAt: aligned, dueAt: aligned, deadlineAt: deadline, lateUntil: deadline.addingTimeInterval(lateWindow),
                    exceedsMaxInterval: aligned > normalDeadline, anchor: t)
    }

    /// After a miss: the virtual anchor is the deadline that passed (capped at dose time + half a period so it cannot
    /// drift), so two consecutive ringing alarms are never further apart than the maximum gap.
    private func doseAfterMiss(_ previous: Dose) -> Dose {
        let anchor = min(previous.deadlineAt, previous.slotAt.addingTimeInterval(halfPeriod))
        var slot = previous.slotAt.addingTimeInterval(period)
        while slot <= previous.deadlineAt { slot = slot.addingTimeInterval(period) }
        return dose(slot: slot, anchor: anchor)
    }

    /// After a pause: the next dose starts from the first dose time at or after the pause ends.
    private func doseAfterPause(_ end: Date) -> Dose {
        doseFromMainTime(firstSlot(atOrAfter: end))
    }

    /// A dose at its scheduled time, as if the previous one was taken on time one period before.
    private func doseFromMainTime(_ slot: Date) -> Dose {
        dose(slot: slot, anchor: slot.addingTimeInterval(-min(maxInterval, period)))
    }

    private func chain(for dose: Dose) -> [ReminderEvent] {
        func event(_ date: Date, _ kind: ReminderKind) -> ReminderEvent {
            ReminderEvent(date: date, kind: kind, requiresSound: kind == .deadline || kind == .overdue, dueAt: dose.dueAt, deadlineAt: dose.deadlineAt)
        }
        let due = dose.dueAt, deadline = dose.deadlineAt
        var list = [event(due, .main)]
        let repeatStep = max(60, settings.repeatInterval)
        for i in stride(from: 1, through: max(0, settings.repeatCount), by: 1) {
            list.append(event(due.addingTimeInterval(TimeInterval(i) * repeatStep), .repeat))
        }
        let lastRepeat = due.addingTimeInterval(TimeInterval(max(0, settings.repeatCount)) * repeatStep)
        let finalStart = deadline.addingTimeInterval(-max(0, settings.finalWindow))
        var hourly = lastRepeat.addingTimeInterval(max(60, settings.hourlyInterval))
        while hourly < finalStart {
            list.append(event(hourly, .hourly))
            hourly = hourly.addingTimeInterval(max(60, settings.hourlyInterval))
        }
        var final = finalStart
        while final < deadline {
            if final >= due { list.append(event(final, .final)) }
            final = final.addingTimeInterval(max(60, settings.finalInterval))
        }
        list.append(event(deadline, .deadline))
        // Past the deadline, all ringing: repeats like after the main time, then the final cadence until `overdueBurst`,
        // then hourly until the late window ends.
        let burstEnd = deadline.addingTimeInterval(overdueBurst)
        var overdue: [Date] = (0..<max(0, settings.repeatCount)).map { deadline.addingTimeInterval(TimeInterval($0 + 1) * repeatStep) }
        var next = (overdue.last ?? deadline).addingTimeInterval(max(60, settings.finalInterval))
        while next <= burstEnd {
            overdue.append(next)
            next = next.addingTimeInterval(max(60, settings.finalInterval))
        }
        next = max(burstEnd, overdue.last ?? deadline).addingTimeInterval(max(60, settings.hourlyInterval))
        while next <= dose.lateUntil {
            overdue.append(next)
            next = next.addingTimeInterval(max(60, settings.hourlyInterval))
        }
        let before = list.filter { $0.date >= due && $0.date <= deadline }
        return before + overdue.filter { $0 <= dose.lateUntil }.map { event($0, .overdue) }
    }

    private func priority(_ kind: ReminderKind) -> Int {
        switch kind {
        case .deadline: 5
        case .overdue: 4
        case .main: 3
        case .repeat: 2
        case .final: 1
        case .hourly: 0
        }
    }
}
