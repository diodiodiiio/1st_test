import Foundation

struct WeekHelper {
    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        cal.firstWeekday = 2 // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }()

    static func weekID(for date: Date) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = c.yearForWeekOfYear ?? 0
        let w = c.weekOfYear ?? 0
        return "\(y)-W\(String(format: "%02d", w))"
    }

    static func dateRange(for weekID: String) -> (start: Date, end: Date)? {
        let parts = weekID.split(separator: "-W")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else { return nil }

        var c = DateComponents()
        c.yearForWeekOfYear = year
        c.weekOfYear = week
        c.weekday = 2 // Monday
        guard let start = calendar.date(from: c),
              let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
        return (start, end)
    }

    static func weekLabel(for weekID: String) -> String {
        guard let range = dateRange(for: weekID) else { return weekID }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日"
        let last = calendar.date(byAdding: .day, value: -1, to: range.end)!
        return "\(fmt.string(from: range.start))〜\(fmt.string(from: last))"
    }

    static func currentWeekID() -> String { weekID(for: Date()) }

    static func recentWeekIDs(count: Int = 8) -> [String] {
        (0..<count).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()).map { weekID(for: $0) }
        }
    }
}
