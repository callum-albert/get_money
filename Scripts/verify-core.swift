import Foundation

@main
struct VerifyCore {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
        }
        var settings = WorkSettings()
        settings.mode = .daily; settings.salary = 800
        var data = EarningsData()
        data.save(settings, on: date(1), calendar: calendar)
        var count = 0
        func check(_ actual: Double, _ expected: Double, _ label: String) {
            precondition(abs(actual - expected) < 0.0001, "\(label): got \(actual), expected \(expected)")
            count += 1
            print("PASS \(label)")
        }
        func amount(_ now: Date, _ source: EarningsData) -> Double {
            EarningsEngine.daily(on: now, asOf: now, data: source, calendar: calendar).amount
        }
        check(amount(date(1, 8), data), 0, "上班前")
        check(amount(date(1, 10), data), 100, "上班一小时")
        check(amount(date(1, 12, 30), data), 300, "午休冻结")
        check(amount(date(1, 18), data), 800, "下班封顶")
        check(amount(date(6, 15), data), 0, "周末不计薪")
        check(amount(date(2), data), 0, "午夜归零")
        var paused = data
        paused.togglePause(at: date(1, 11), calendar: calendar)
        paused.togglePause(at: date(1, 14), calendar: calendar)
        check(amount(date(1, 18), paused), 600, "暂停跨午休只扣工作时间")
        paused.setLeave(true, on: date(1, 15), calendar: calendar)
        check(amount(date(1, 18), paused), 0, "整天请假")
        paused.setLeave(false, on: date(1, 16), calendar: calendar)
        check(amount(date(1, 18), paused), 600, "取消请假保留暂停")
        var open = data
        open.togglePause(at: date(1, 10), calendar: calendar)
        check(amount(date(1, 18), open), 100, "未恢复暂停")
        check(amount(date(2, 18), open), 800, "暂停不延续到次日")
        settings.salary = 1600
        data.save(settings, on: date(2), calendar: calendar)
        check(amount(date(1, 18), data), 800, "修改工资不改往日")
        check(amount(date(2, 18), data), 1600, "新工资当天生效")
        check(EarningsEngine.month(containing: date(1), asOf: date(2, 18), data: data, calendar: calendar).reduce(0) { $0 + $1.amount }, 2400, "月度累计")
        settings.mode = .monthly; settings.salary = 22000
        var monthly = EarningsData(); monthly.save(settings, on: date(1), calendar: calendar)
        check(amount(date(1, 18), monthly), 1000, "月薪按当月22工作日")
        settings.fixedDays = 20; monthly.save(settings, on: date(1), calendar: calendar)
        check(amount(date(1, 18), monthly), 1100, "固定计薪天数")
        let decoded = try JSONDecoder().decode(EarningsData.self, from: JSONEncoder().encode(data))
        check(amount(date(2, 18), decoded), 1600, "本地数据序列化往返")
        settings.mode = .daily; settings.salary = 600; settings.startMinute = 600; settings.endMinute = 960; settings.lunchEnabled = false
        var custom = EarningsData(); custom.save(settings, on: date(1), calendar: calendar)
        check(amount(date(1, 13), custom), 300, "自定义时段")
        settings.endMinute = settings.startMinute
        precondition(settings.validationError != nil)
        print("PASS 非法时段拦截")
        print("\(count + 1) checks passed")
    }
}
