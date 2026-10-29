import Foundation

/// Một lần uống đang chờ hoặc sẽ tới.
public struct Dose: Equatable, Sendable {
    /// Giờ chính (giờ VN) mà lần này thuộc về.
    public var slotAt: Date
    /// Mốc nhắc chính.
    public var dueAt: Date
    /// Hạn chót, tại đây báo thức có tiếng.
    public var deadlineAt: Date
    /// Uống sau hạn chót mà trước mốc này thì tính trễ, quá mốc này mới tính hụt.
    public var lateUntil: Date
    /// Đúng khi lần này đã bị "về lại giờ gốc" và vượt khoảng tối đa.
    public var exceedsMaxInterval: Bool
    /// Mốc tính hạn chót: lần uống trước, hoặc mốc ảo sau một lần hụt hay tạm dừng.
    var anchor: Date
}

public enum ReminderKind: String, Codable, Sendable {
    case main, `repeat`, hourly, final, deadline
    /// Sau hạn chót, nhắc tiếp có tiếng tới khi uống hoặc hết cửa sổ trễ.
    case overdue
}

public struct ReminderEvent: Equatable, Sendable {
    public var date: Date
    public var kind: ReminderKind
    /// Báo thức có tiếng bất kể chế độ máy. Đúng từ hạn chót trở đi.
    public var requiresSound: Bool
    public var dueAt: Date
    public var deadlineAt: Date
}

/// Kết quả xem trước thao tác "về lại giờ gốc".
public struct ResetPreview: Equatable, Sendable {
    public var dueAt: Date
    public var deadlineAt: Date
    /// Đúng khi lần đó cách lần uống trước quá khoảng tối đa, app phải cảnh báo.
    public var exceedsMaxInterval: Bool
}

/// Tính lịch nhắc từ cài đặt và lịch sử uống. Không đọc giờ máy, `now` luôn là tham số.
public struct Planner: Sendable {
    public var settings: ReminderSettings
    /// Lịch sử các lần đã uống (`status == .taken`).
    public var history: [DoseRecord]

    public init(settings: ReminderSettings = ReminderSettings(), history: [DoseRecord] = []) {
        self.settings = settings
        self.history = history
    }

    // MARK: Truy vấn

    /// Lần uống đang chờ tại `now`.
    public func currentDose(now: Date) -> Dose { walk(now: now).dose }

    /// Mốc nhắc kế tiếp.
    public func nextReminder(now: Date) -> Date { currentDose(now: now).dueAt }

    public func missedCount(now: Date) -> Int { walk(now: now).missed }

    /// Số lần uống sau hạn chót nhưng còn trong cửa sổ trễ.
    public func lateCount(now: Date) -> Int { walk(now: now).late }

    /// Số lần đã uống kể từ lần nhập hoặc thêm viên gần nhất, không đếm viên thì kể từ đầu.
    public func daysTaken(now: Date) -> Int {
        let since = settings.pills?.countingSince ?? .distantPast
        return takes(upTo: now).filter { $0.takenAt! >= since }.count
    }

    public func lastTaken(now: Date) -> DoseRecord? { takes(upTo: now).last }

    /// Lịch sử đầy đủ để hiển thị: lần uống (đúng hạn hoặc trễ), lần hụt, lần rơi vào tạm dừng.
    public func timeline(now: Date) -> [DoseRecord] { walk(now: now).records }

    /// Mốc kêu lại khi bấm hoãn. Không vượt quá hạn chót, hạn chót giữ nguyên.
    public func snoozeUntil(now: Date) -> Date {
        let wake = now.addingTimeInterval(max(60, settings.snoozeInterval))
        let deadline = currentDose(now: now).deadlineAt
        return now < deadline ? min(wake, deadline) : wake
    }

    /// Chuỗi mốc nhắc trong `horizonDays` ngày tới, sắp theo thời gian, không trùng mốc.
    /// Các lần sau lần đang chờ được tính như thể không có xác nhận; bấm "Đã uống" thì app tính lại.
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

    /// Xem trước "về lại giờ gốc" cho lần kế. `nil` khi lần đang chờ không nối thẳng từ một lần uống
    /// (đã hụt hoặc tạm dừng thì lần kế vốn đã tính từ giờ chính).
    public func resetPreview(now: Date) -> ResetPreview? {
        let state = walk(now: now)
        guard state.followsTake, var take = takes(upTo: now).last else { return nil }
        take.nextAtMainTime = true
        let dose = doseAfterTake(take)
        return ResetPreview(dueAt: dose.dueAt, deadlineAt: dose.deadlineAt, exceedsMaxInterval: dose.exceedsMaxInterval)
    }

    // MARK: Thao tác

    /// Bấm "Đã uống" tại `now`. Trừ một viên nếu có đếm.
    @discardableResult
    public mutating func markTaken(at now: Date) -> DoseRecord {
        let consumed = settings.pills?.consume() ?? false
        let record = DoseRecord(scheduledAt: currentDose(now: now).dueAt, takenAt: now, status: .taken, consumedPill: consumed)
        history.append(record)
        return record
    }

    /// Hoàn tác lần "Đã uống" gần nhất nếu còn trong `undoWindow`.
    @discardableResult
    public mutating func undoLastTaken(now: Date) -> Bool {
        guard let last = takes(upTo: now).last, now.timeIntervalSince(last.takenAt!) <= settings.undoWindow,
              let index = history.firstIndex(where: { $0.id == last.id }) else { return false }
        history.remove(at: index)
        if last.consumedPill { settings.pills?.restore() }
        return true
    }

    /// Sửa thời điểm uống trong lịch sử.
    public mutating func editTakenTime(id: UUID, to date: Date) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].takenAt = date
    }

    /// "Về lại giờ gốc" cho lần kế. Trả kết quả để app cảnh báo nếu vượt khoảng tối đa.
    @discardableResult
    public mutating func resetToMainTime(now: Date) -> ResetPreview? {
        guard let preview = resetPreview(now: now), let last = takes(upTo: now).last,
              let index = history.firstIndex(where: { $0.id == last.id }) else { return nil }
        history[index].nextAtMainTime = true
        return preview
    }

    /// "Tạm dừng nhắc N ngày" bắt đầu từ `now`.
    public mutating func pause(days: Int, now: Date) {
        guard days > 0 else { return }
        settings.pauses.append(PausePeriod(start: now, end: now.addingTimeInterval(TimeInterval(days) * VietnamClock.day)))
    }

    /// Kết thúc tạm dừng ngay tại `now`.
    public mutating func resume(now: Date) {
        for i in settings.pauses.indices where settings.pauses[i].contains(now) {
            settings.pauses[i].end = now
        }
    }

    /// Thêm viên, hoặc bắt đầu đếm nếu trước đó chưa đếm.
    public mutating func addPills(_ count: Int, now: Date) {
        if settings.pills == nil {
            settings.pills = PillCounter(count: count, at: now)
        } else {
            settings.pills?.add(count, at: now)
        }
    }

    // MARK: Tính lịch

    private struct WalkState {
        var dose: Dose
        var missed = 0
        var late = 0
        var records: [DoseRecord] = []
        /// Lần đang chờ được tính thẳng từ lần uống cuối, chưa qua hụt hay tạm dừng.
        var followsTake = false
    }

    private func takes(upTo now: Date) -> [DoseRecord] {
        history
            .filter { $0.status == .taken && ($0.takenAt.map { $0 <= now } ?? false) }
            .sorted { $0.takenAt! < $1.takenAt! }
    }

    /// Đi lần lượt qua các lần uống tới `now`, đếm hụt và trả lần đang chờ.
    private func walk(now: Date) -> WalkState {
        let taken = takes(upTo: now)
        guard let first = taken.first else {
            // Chưa có lịch sử: lần đầu là giờ chính kế tiếp sau `now`.
            var state = WalkState(dose: doseFromMainTime(VietnamClock.firstMainTime(after: now, hour: settings.mainHour, minute: settings.mainMinute)))
            advance(&state, before: now)
            return state
        }
        var state = WalkState(dose: doseAfterTake(first), records: [first], followsTake: true)
        for take in taken.dropFirst() {
            advance(&state, before: take.takenAt!)
            if take.takenAt! > state.dose.deadlineAt {
                var record = take
                record.status = .late
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

    /// Bỏ qua các lần rơi vào tạm dừng và đếm các lần đã qua hạn chót trước thời điểm `t`.
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
    private var lateWindow: TimeInterval { max(0, settings.lateWindow) }

    private func dose(slot: Date, anchor: Date) -> Dose {
        let deadline = anchor.addingTimeInterval(maxInterval)
        return Dose(slotAt: slot, dueAt: min(slot, deadline), deadlineAt: deadline, lateUntil: deadline.addingTimeInterval(lateWindow),
                    exceedsMaxInterval: false, anchor: anchor)
    }

    /// Sau lần uống lúc T: lần kế thuộc giờ chính đầu tiên sau T + 12 giờ, tức lần uống T được tính
    /// cho giờ chính gần nó nhất. Mốc nhắc = min(giờ chính đó, T + khoảng tối đa).
    private func doseAfterTake(_ take: DoseRecord) -> Dose {
        let t = take.takenAt!
        let slot = VietnamClock.firstMainTime(after: t.addingTimeInterval(12 * 3600), hour: settings.mainHour, minute: settings.mainMinute)
        guard take.nextAtMainTime else { return dose(slot: slot, anchor: t) }
        let normalDeadline = t.addingTimeInterval(maxInterval)
        let deadline = max(slot, normalDeadline)
        return Dose(slotAt: slot, dueAt: slot, deadlineAt: deadline, lateUntil: deadline.addingTimeInterval(lateWindow),
                    exceedsMaxInterval: slot > normalDeadline, anchor: t)
    }

    /// Sau một lần hụt: mốc ảo là hạn chót vừa qua (giới hạn không trễ hơn giờ chính + 12 giờ để không trôi),
    /// nên hai báo thức có tiếng liên tiếp không bao giờ cách nhau quá khoảng tối đa.
    private func doseAfterMiss(_ previous: Dose) -> Dose {
        let anchor = min(previous.deadlineAt, previous.slotAt.addingTimeInterval(12 * 3600))
        var slot = previous.slotAt.addingTimeInterval(VietnamClock.day)
        while slot <= previous.deadlineAt { slot = slot.addingTimeInterval(VietnamClock.day) }
        return dose(slot: slot, anchor: anchor)
    }

    /// Hết tạm dừng: lần kế tính từ giờ chính đầu tiên kể từ lúc hết dừng.
    private func doseAfterPause(_ end: Date) -> Dose {
        doseFromMainTime(VietnamClock.firstMainTime(atOrAfter: end, hour: settings.mainHour, minute: settings.mainMinute))
    }

    /// Lần nhắc đúng giờ chính, như thể lần trước uống đúng giờ chính hôm trước.
    private func doseFromMainTime(_ slot: Date) -> Dose {
        dose(slot: slot, anchor: slot.addingTimeInterval(-min(maxInterval, VietnamClock.day)))
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
        // Quá hạn chót, tất cả có tiếng: nhắc lại như sau mốc chính, rồi theo nhịp cuối tới hết `overdueBurst`,
        // rồi theo nhịp giờ tới hết cửa sổ trễ.
        let burstEnd = deadline.addingTimeInterval(max(0, settings.overdueBurst))
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
