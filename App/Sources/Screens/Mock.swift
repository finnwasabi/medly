import Foundation

// Dữ liệu giả cho P2 (mockup). P4b thay bằng dữ liệu thật từ NersCore.
enum MockTodayState: String {
    case upcoming, taken, overdue
}

struct MockDay: Identifiable {
    let id = UUID()
    let day: Int
    let status: DoseStatus
}

struct MockEntry: Identifiable {
    let id = UUID()
    let date: String
    let time: String
    let status: DoseStatus
    let note: String?
}

enum Mock {
    static let message = "Uống thuốc rồi đi ngủ sớm nha, bay mệt rồi đó."
    static let pillsTotal = 28
    static let pillsRemaining = 5
    static let refillDaysBefore = 7
    static let localPlace = "Paris"
    static let today = 29

    static let week: [DoseStatus] = [.taken, .taken, .late, .taken, .taken, .taken, .upcoming]

    static let month: [MockDay] = (1...31).map { day in
        let status: DoseStatus = switch day {
        case 9: .late
        case 14: .missed
        case 20, 21: .paused
        case 22: .late
        case 30, 31: .upcoming
        default: .taken
        }
        return MockDay(day: day, status: status)
    }

    static let entries: [MockEntry] = [
        MockEntry(date: "Thứ Năm, 29/10", time: "20:58", status: .taken, note: nil),
        MockEntry(date: "Thứ Tư, 28/10", time: "21:02", status: .taken, note: "tại Paris 16:02"),
        MockEntry(date: "Thứ Ba, 27/10", time: "23:40", status: .late, note: "trễ 2 giờ 40 phút"),
        MockEntry(date: "Thứ Hai, 26/10", time: "20:55", status: .taken, note: nil),
        MockEntry(date: "Chủ Nhật, 25/10", time: "21:00", status: .taken, note: nil),
    ]
}
