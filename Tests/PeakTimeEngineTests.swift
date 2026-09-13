import XCTest
@testable import ClaudeUsageShared

final class PeakTimeEngineTests: XCTestCase {
    var engine: PeakTimeEngine!
    var ptCalendar: Calendar!

    override func setUp() {
        super.setUp()
        engine = PeakTimeEngine.shared
        ptCalendar = engine.ptCalendar
    }

    func makeDate(year: Int = 2026, month: Int = 9, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.timeZone = engine.pacificTimeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return ptCalendar.date(from: components)!
    }

    // 2026-09-14 is a Monday (weekday = 2)
    func testMondayPeakBoundaries() {
        // Monday 4:59:59 AM PT -> Off-Peak (Peak imminent in 1 second)
        let prePeak = makeDate(day: 14, hour: 4, minute: 59, second: 59)
        XCTAssertFalse(engine.isPeak(at: prePeak))
        let preStatus = engine.currentStatus(at: prePeak)
        if case .approachingPeak(let startsAt, let remaining) = preStatus {
            XCTAssertEqual(Int(remaining), 1)
            let startComponents = ptCalendar.dateComponents([.hour, .minute], from: startsAt)
            XCTAssertEqual(startComponents.hour, 5)
            XCTAssertEqual(startComponents.minute, 0)
        } else {
            XCTFail("Expected approachingPeak at 4:59:59 AM, got: \(preStatus)")
        }

        // Monday 5:00:00 AM PT -> Peak Active
        let peakStart = makeDate(day: 14, hour: 5, minute: 0, second: 0)
        XCTAssertTrue(engine.isPeak(at: peakStart))
        let startStatus = engine.currentStatus(at: peakStart)
        if case .peakActive(let endsAt, let remaining) = startStatus {
            XCTAssertEqual(Int(remaining), 6 * 3600)
            let endComponents = ptCalendar.dateComponents([.hour, .minute], from: endsAt)
            XCTAssertEqual(endComponents.hour, 11)
            XCTAssertEqual(endComponents.minute, 0)
        } else {
            XCTFail("Expected peakActive at 5:00:00 AM, got: \(startStatus)")
        }

        // Monday 10:59:59 AM PT -> Peak Active (1 second remaining)
        let peakEndMinusOne = makeDate(day: 14, hour: 10, minute: 59, second: 59)
        XCTAssertTrue(engine.isPeak(at: peakEndMinusOne))
        let endMinusStatus = engine.currentStatus(at: peakEndMinusOne)
        if case .peakActive(_, let remaining) = endMinusStatus {
            XCTAssertEqual(Int(remaining), 1)
        } else {
            XCTFail("Expected peakActive at 10:59:59 AM, got: \(endMinusStatus)")
        }

        // Monday 11:00:00 AM PT -> Peak Ended (Off-Peak)
        let peakEnd = makeDate(day: 14, hour: 11, minute: 0, second: 0)
        XCTAssertFalse(engine.isPeak(at: peakEnd))
        let endStatus = engine.currentStatus(at: peakEnd)
        if case .offPeak(let nextDate, _) = endStatus {
            let nextComponents = ptCalendar.dateComponents([.weekday, .hour, .minute], from: nextDate)
            XCTAssertEqual(nextComponents.weekday, 3) // Tuesday
            XCTAssertEqual(nextComponents.hour, 5)
        } else {
            XCTFail("Expected offPeak at 11:00:00 AM, got: \(endStatus)")
        }
    }

    // 2026-09-18 is Friday, 2026-09-19 is Saturday, 2026-09-20 is Sunday
    func testWeekendOffPeakAllDay() {
        // Saturday 8:00 AM PT
        let saturday = makeDate(day: 19, hour: 8, minute: 0)
        XCTAssertFalse(engine.isPeak(at: saturday))

        let satStatus = engine.currentStatus(at: saturday)
        if case .offPeak(let nextStart, _) = satStatus {
            let nextComponents = ptCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 5)
        } else {
            XCTFail("Expected offPeak on Saturday, got: \(satStatus)")
        }

        // Sunday 2:00 PM PT
        let sunday = makeDate(day: 20, hour: 14, minute: 0)
        XCTAssertFalse(engine.isPeak(at: sunday))

        let sunStatus = engine.currentStatus(at: sunday)
        if case .offPeak(let nextStart, _) = sunStatus {
            let nextComponents = ptCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 5)
        } else {
            XCTFail("Expected offPeak on Sunday, got: \(sunStatus)")
        }
    }

    func testFridayAfternoonPointsToMonday() {
        // Friday 2:00 PM PT
        let fridayAfternoon = makeDate(day: 18, hour: 14, minute: 0)
        XCTAssertFalse(engine.isPeak(at: fridayAfternoon))

        let status = engine.currentStatus(at: fridayAfternoon)
        if case .offPeak(let nextStart, let untilNext) = status {
            let nextComponents = ptCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 5)
            // Friday 14:00 to Monday 05:00 = 10h + 24h + 24h + 5h = 63 hours
            XCTAssertEqual(Int(untilNext), 63 * 3600)
        } else {
            XCTFail("Expected offPeak on Friday afternoon, got: \(status)")
        }
    }

    func testRegionalWindowsConversion() {
        let mondayNoon = makeDate(day: 14, hour: 12, minute: 0)
        let windows = engine.regionalWindows(for: mondayNoon)

        let ptWindow = windows.first { $0.regionCode == "PT" }
        XCTAssertEqual(ptWindow?.windowString, "5:00 AM – 11:00 AM")

        let etWindow = windows.first { $0.regionCode == "ET" }
        XCTAssertEqual(etWindow?.windowString, "8:00 AM – 2:00 PM")

        let gmtWindow = windows.first { $0.regionCode == "GMT" }
        XCTAssertEqual(gmtWindow?.windowString, "1:00 PM – 7:00 PM")

        let cetWindow = windows.first { $0.regionCode == "CET" }
        XCTAssertEqual(cetWindow?.windowString, "2:00 PM – 8:00 PM")
    }

    func testDayTimelineSlice() {
        let mondayMorning = makeDate(day: 14, hour: 5, minute: 0)
        let slice = engine.dayTimelineSlice(for: mondayMorning, targetTimezone: engine.pacificTimeZone)

        XCTAssertTrue(slice.hasPeakToday)
        // 5 AM / 24h = 5 / 24 = ~0.2083
        XCTAssertEqual(slice.peakStartFraction, 5.0 / 24.0, accuracy: 0.001)
        // 11 AM / 24h = 11 / 24 = ~0.4583
        XCTAssertEqual(slice.peakEndFraction, 11.0 / 24.0, accuracy: 0.001)
    }
}
