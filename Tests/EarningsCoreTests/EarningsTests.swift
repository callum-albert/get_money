import XCTest
@testable import EarningsCore

final class EarningsTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return c
    }
    func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 6) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    func fixture() -> EarningsData {
        var settings = WorkSettings()
        settings.mode = .daily; settings.salary = 800
        var data = EarningsData()
        data.save(settings, on: date(1), calendar: calendar)
        return data
    }
    func result(_ now: Date, _ data: EarningsData) -> DayEarnings {
        EarningsEngine.daily(on: now, asOf: now, data: data, calendar: calendar)
    }
    func testWorkdayBoundaries() {
        let data = fixture()
        XCTAssertEqual(result(date(1, 8), data).amount, 0)
        XCTAssertEqual(result(date(1, 9), data).amount, 0)
        XCTAssertEqual(result(date(1, 10), data).amount, 100, accuracy: 0.001)
        XCTAssertEqual(result(date(1, 12, 30), data).amount, 300, accuracy: 0.001)
        XCTAssertEqual(result(date(1, 13), data).amount, 300, accuracy: 0.001)
        XCTAssertEqual(result(date(1, 18), data).amount, 800, accuracy: 0.001)
        XCTAssertEqual(result(date(1, 23), data).amount, 800, accuracy: 0.001)
        XCTAssertEqual(result(date(6, 15), data).amount, 0)
    }
    func testPauseOverLunchDoesNotDoubleDeduct() {
        var data = fixture()
        data.togglePause(at: date(1, 11), calendar: calendar)
        data.togglePause(at: date(1, 14), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 600, accuracy: 0.001)
    }
    func testOpenPauseDoesNotCarryIntoTomorrow() {
        var data = fixture()
        data.togglePause(at: date(1, 10), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 100, accuracy: 0.001)
        XCTAssertEqual(result(date(2, 18), data).amount, 800, accuracy: 0.001)
    }
    func testLeaveAndUndoPreservePause() {
        var data = fixture()
        data.togglePause(at: date(1, 10), calendar: calendar)
        data.togglePause(at: date(1, 11), calendar: calendar)
        data.setLeave(true, on: date(1, 15), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 0)
        data.setLeave(false, on: date(1, 16), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 700, accuracy: 0.001)
    }
    func testMonthlyDivisorAndFixedDays() {
        var settings = WorkSettings()
        settings.salary = 22000
        XCTAssertEqual(EarningsEngine.plannedDays(in: date(1), settings: settings, calendar: calendar), 22)
        var data = EarningsData()
        data.save(settings, on: date(1), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 1000, accuracy: 0.001)
        settings.fixedDays = 20
        data.save(settings, on: date(1), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 1100, accuracy: 0.001)
    }
    func testVersionsKeepPastAndNoBackfill() {
        var data = fixture()
        var settings = WorkSettings(); settings.mode = .daily; settings.salary = 1600
        data.save(settings, on: date(2), calendar: calendar)
        XCTAssertEqual(result(date(1, 18), data).amount, 800)
        XCTAssertEqual(result(date(2, 18), data).amount, 1600)
        XCTAssertEqual(result(date(29, 18, month: 5), data).amount, 0)
        XCTAssertEqual(EarningsEngine.month(containing: date(1), asOf: date(2, 18), data: data, calendar: calendar).reduce(0) { $0 + $1.amount }, 2400)
    }
    func testCustomScheduleAndValidation() {
        var settings = WorkSettings(); settings.mode = .daily; settings.salary = 600
        settings.startMinute = 10 * 60; settings.endMinute = 16 * 60; settings.lunchEnabled = false
        var data = EarningsData(); data.save(settings, on: date(1), calendar: calendar)
        XCTAssertEqual(result(date(1, 13), data).amount, 300)
        settings.endMinute = settings.startMinute
        XCTAssertNotNil(settings.validationError)
        settings.endMinute = 18 * 60; settings.salary = .nan
        XCTAssertNotNil(settings.validationError)
    }
    func testOverlappingPausesAndSerialization() throws {
        var data = fixture()
        var record = DayRecord()
        record.pauses = [Pause(start: date(1, 10), end: date(1, 12)), Pause(start: date(1, 11), end: date(1, 14))]
        data.records[EarningsEngine.dayKey(date(1), calendar: calendar)] = record
        let decoded = try JSONDecoder().decode(EarningsData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(result(date(1, 18), decoded).amount, 500, accuracy: 0.001)
    }
    func testMidnightResetsAndFutureDoesNotEarn() {
        let data = fixture()
        XCTAssertEqual(result(date(2), data).amount, 0)
        XCTAssertEqual(EarningsEngine.daily(on: date(3), asOf: date(2, 18), data: data, calendar: calendar).amount, 0)
    }
}
