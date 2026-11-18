import Foundation

public enum SalaryMode: String, Codable, CaseIterable, Sendable {
    case monthly, daily
}

public struct WorkSettings: Codable, Equatable, Sendable {
    public var mode: SalaryMode = .monthly
    public var salary: Double = 10000
    /// nil: 按当月计划工作日折算；非 nil: 固定计薪天数。
    public var fixedDays: Double? = nil
    public var startMinute: Int = 9 * 60
    public var endMinute: Int = 18 * 60
    public var lunchEnabled: Bool = true
    public var lunchStart: Int = 12 * 60
    public var lunchEnd: Int = 13 * 60
    /// Calendar weekday: Sunday = 1
    public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public init() {}

    public var validationError: String? {
        if !salary.isFinite || salary <= 0 || salary > 100_000_000 { return "请输入大于 0 且不超过一亿元的工资。" }
        if let fixedDays, !fixedDays.isFinite || fixedDays <= 0 || fixedDays > 31 { return "固定计薪天数应大于 0 且不超过 31。" }
        if startMinute < 0 || endMinute >= 1440 || startMinute >= endMinute { return "下班时间必须晚于上班时间，暂不支持跨夜班次。" }
        if weekdays.isEmpty || !weekdays.isSubset(of: Set(1...7)) { return "请至少选择一个工作日。" }
        if lunchEnabled && !(startMinute <= lunchStart && lunchStart < lunchEnd && lunchEnd <= endMinute) { return "午休需位于上下班时间内，结束时间必须晚于开始时间。" }
        if endMinute - startMinute - (lunchEnabled ? lunchEnd - lunchStart : 0) <= 0 { return "每天至少需要有一分钟工作时间。" }
        return nil
    }
}

public struct SettingsVersion: Codable, Sendable {
    public var effectiveDay: Date
    public var settings: WorkSettings
    public init(effectiveDay: Date, settings: WorkSettings) {
        self.effectiveDay = effectiveDay
        self.settings = settings
    }
}

public struct Pause: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date?
    public init(start: Date, end: Date? = nil) { self.start = start; self.end = end }
}

public struct DayRecord: Codable, Equatable, Sendable {
    public var isLeave = false
    public var pauses: [Pause] = []
    public init() {}
}

public struct EarningsData: Codable, Sendable {
    public var versions: [SettingsVersion] = []
    public var records: [String: DayRecord] = [:]
    public init() {}

    public func settings(on date: Date, calendar: Calendar = .current) -> WorkSettings? {
        let day = calendar.startOfDay(for: date)
        return versions.filter { $0.effectiveDay <= day }.max { $0.effectiveDay < $1.effectiveDay }?.settings
    }

    public mutating func save(_ settings: WorkSettings, on date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        versions.removeAll { calendar.isDate($0.effectiveDay, inSameDayAs: day) }
        versions.append(SettingsVersion(effectiveDay: day, settings: settings))
        versions.sort { $0.effectiveDay < $1.effectiveDay }
    }

    public mutating func togglePause(at date: Date, calendar: Calendar = .current) {
        let key = EarningsEngine.dayKey(date, calendar: calendar)
        var record = records[key, default: DayRecord()]
        guard !record.isLeave else { return }
        if let index = record.pauses.lastIndex(where: { $0.end == nil }) {
            record.pauses[index].end = max(date, record.pauses[index].start)
        } else {
            record.pauses.append(Pause(start: date))
        }
        records[key] = record
    }

    public mutating func setLeave(_ leave: Bool, on date: Date, calendar: Calendar = .current) {
        let key = EarningsEngine.dayKey(date, calendar: calendar)
        var record = records[key, default: DayRecord()]
        record.isLeave = leave
        // 标记整天请假时关闭暂停；取消请假仍保留已有暂停历史。
        if leave {
            for index in record.pauses.indices where record.pauses[index].end == nil {
                record.pauses[index].end = max(date, record.pauses[index].start)
            }
        }
        records[key] = record
    }
}

public struct DayEarnings: Sendable {
    public let date: Date
    public let amount: Double
    public let target: Double
    public let workedSeconds: TimeInterval
    public let plannedSeconds: TimeInterval
    public let status: String
    public let isPaused: Bool
    public let isLeave: Bool
    public var progress: Double { target > 0 ? min(1, max(0, amount / target)) : 0 }
}

public enum EarningsEngine {
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func plannedDays(in date: Date, settings: WorkSettings, calendar: Calendar = .current) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return 0 }
        return days.filter { index in
            guard let day = calendar.date(byAdding: .day, value: index - 1, to: month.start) else { return false }
            return settings.weekdays.contains(calendar.component(.weekday, from: day))
        }.count
    }

    public static func intervals(on date: Date, settings: WorkSettings, calendar: Calendar = .current) -> [DateInterval] {
        guard settings.validationError == nil,
              settings.weekdays.contains(calendar.component(.weekday, from: date)) else { return [] }
        func time(_ minute: Int) -> Date {
            calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date)!
        }
        if settings.lunchEnabled {
            return [(settings.startMinute, settings.lunchStart), (settings.lunchEnd, settings.endMinute)]
                .filter { $0.0 < $0.1 }.map { DateInterval(start: time($0.0), end: time($0.1)) }
        }
        return [DateInterval(start: time(settings.startMinute), end: time(settings.endMinute))]
    }

    public static func daily(on date: Date, asOf now: Date, data: EarningsData, calendar: Calendar = .current) -> DayEarnings {
        let record = data.records[dayKey(date, calendar: calendar), default: DayRecord()]
        guard let settings = data.settings(on: date, calendar: calendar), settings.validationError == nil else {
            return DayEarnings(date: date, amount: 0, target: 0, workedSeconds: 0, plannedSeconds: 0, status: "未设置", isPaused: false, isLeave: record.isLeave)
        }
        let slots = intervals(on: date, settings: settings, calendar: calendar)
        let duration = slots.reduce(0) { $0 + $1.duration }
        let divisor = settings.fixedDays ?? Double(plannedDays(in: date, settings: settings, calendar: calendar))
        let target = slots.isEmpty ? 0 : (settings.mode == .daily ? settings.salary : settings.salary / max(1, divisor))
        let isPaused = record.pauses.contains { $0.end == nil && $0.start <= now }
        var worked: TimeInterval = 0
        for slot in slots {
            let end = min(now, slot.end)
            guard end > slot.start else { continue }
            var segments: [(Date, Date)] = record.pauses.compactMap { pause in
                let a = max(slot.start, pause.start)
                let b = min(end, pause.end ?? end)
                return a < b ? (a, b) : nil
            }.sorted { $0.0 < $1.0 }
            // 合并暂停区间，确保重复/重叠记录不会重复扣减。
            var excluded: TimeInterval = 0
            if var current = segments.first {
                segments.removeFirst()
                for segment in segments {
                    if segment.0 <= current.1 { current.1 = max(current.1, segment.1) }
                    else { excluded += current.1.timeIntervalSince(current.0); current = segment }
                }
                excluded += current.1.timeIntervalSince(current.0)
            }
            worked += max(0, end.timeIntervalSince(slot.start) - excluded)
        }
        if record.isLeave { worked = 0 }
        let status: String
        if record.isLeave { status = "整天请假" }
        else if slots.isEmpty { status = "休息日" }
        else if now < slots[0].start { status = "未开工" }
        else if now >= slots.last!.end { status = "已下班" }
        else if isPaused { status = "已暂停" }
        else if !slots.contains(where: { $0.start <= now && now < $0.end }) { status = "午休中" }
        else { status = "正在进账" }
        return DayEarnings(date: date, amount: duration > 0 ? target * min(1, worked / duration) : 0,
                           target: target, workedSeconds: worked, plannedSeconds: duration,
                           status: status, isPaused: isPaused, isLeave: record.isLeave)
    }

    public static func month(containing date: Date, asOf now: Date, data: EarningsData, calendar: Calendar = .current) -> [DayEarnings] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        return range.compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index - 1, to: interval.start),
                  day <= calendar.startOfDay(for: now) else { return nil }
            return daily(on: day, asOf: now, data: data, calendar: calendar)
        }
    }
}
