import XCTest
@testable import ClaudeUsageShared

final class PeakTimeEngineTests: XCTestCase {
    var engine: PeakTimeEngine!
    var utcCalendar: Calendar!

    override func setUp() {
        super.setUp()
        engine = PeakTimeEngine.shared
        utcCalendar = engine.utcCalendar
    }

    func makeDate(year: Int = 2026, month: Int = 9, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.timeZone = engine.utcTimeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return utcCalendar.date(from: components)!
    }

    // 2026-09-14 is a Monday (weekday = 2)
    func testMondayPeakBoundaries() {
        // Monday 12:59:59 UTC -> Off-Peak (Peak imminent in 1 second)
        let prePeak = makeDate(day: 14, hour: 12, minute: 59, second: 59)
        XCTAssertFalse(engine.isPeak(at: prePeak))
        let preStatus = engine.currentStatus(at: prePeak)
        if case .approachingPeak(let startsAt, let remaining) = preStatus {
            XCTAssertEqual(Int(remaining), 1)
            let startComponents = utcCalendar.dateComponents([.hour, .minute], from: startsAt)
            XCTAssertEqual(startComponents.hour, 13)
            XCTAssertEqual(startComponents.minute, 0)
        } else {
            XCTFail("Expected approachingPeak at 12:59:59 UTC, got: \(preStatus)")
        }

        // Monday 13:00:00 UTC -> Peak Active
        let peakStart = makeDate(day: 14, hour: 13, minute: 0, second: 0)
        XCTAssertTrue(engine.isPeak(at: peakStart))
        let startStatus = engine.currentStatus(at: peakStart)
        if case .peakActive(let endsAt, let remaining) = startStatus {
            XCTAssertEqual(Int(remaining), 6 * 3600)
            let endComponents = utcCalendar.dateComponents([.hour, .minute], from: endsAt)
            XCTAssertEqual(endComponents.hour, 19)
            XCTAssertEqual(endComponents.minute, 0)
        } else {
            XCTFail("Expected peakActive at 13:00:00 UTC, got: \(startStatus)")
        }

        // Monday 18:59:59 UTC -> Peak Active (1 second remaining)
        let peakEndMinusOne = makeDate(day: 14, hour: 18, minute: 59, second: 59)
        XCTAssertTrue(engine.isPeak(at: peakEndMinusOne))
        let endMinusStatus = engine.currentStatus(at: peakEndMinusOne)
        if case .peakActive(_, let remaining) = endMinusStatus {
            XCTAssertEqual(Int(remaining), 1)
        } else {
            XCTFail("Expected peakActive at 18:59:59 UTC, got: \(endMinusStatus)")
        }

        // Monday 19:00:00 UTC -> Peak Ended (Off-Peak)
        let peakEnd = makeDate(day: 14, hour: 19, minute: 0, second: 0)
        XCTAssertFalse(engine.isPeak(at: peakEnd))
        let endStatus = engine.currentStatus(at: peakEnd)
        if case .offPeak(let nextDate, _) = endStatus {
            let nextComponents = utcCalendar.dateComponents([.weekday, .hour, .minute], from: nextDate)
            XCTAssertEqual(nextComponents.weekday, 3) // Tuesday
            XCTAssertEqual(nextComponents.hour, 13)
        } else {
            XCTFail("Expected offPeak at 19:00:00 UTC, got: \(endStatus)")
        }
    }

    // 2026-09-18 is Friday, 2026-09-19 is Saturday, 2026-09-20 is Sunday
    func testWeekendOffPeakAllDay() {
        // Saturday 14:00 UTC
        let saturday = makeDate(day: 19, hour: 14, minute: 0)
        XCTAssertFalse(engine.isPeak(at: saturday))

        let satStatus = engine.currentStatus(at: saturday)
        if case .offPeak(let nextStart, _) = satStatus {
            let nextComponents = utcCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 13)
        } else {
            XCTFail("Expected offPeak on Saturday, got: \(satStatus)")
        }

        // Sunday 14:00 UTC
        let sunday = makeDate(day: 20, hour: 14, minute: 0)
        XCTAssertFalse(engine.isPeak(at: sunday))

        let sunStatus = engine.currentStatus(at: sunday)
        if case .offPeak(let nextStart, _) = sunStatus {
            let nextComponents = utcCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 13)
        } else {
            XCTFail("Expected offPeak on Sunday, got: \(sunStatus)")
        }
    }

    func testFridayAfternoonPointsToMonday() {
        // Friday 20:00 UTC (after peak ended)
        let fridayAfternoon = makeDate(day: 18, hour: 20, minute: 0)
        XCTAssertFalse(engine.isPeak(at: fridayAfternoon))

        let status = engine.currentStatus(at: fridayAfternoon)
        if case .offPeak(let nextStart, let untilNext) = status {
            let nextComponents = utcCalendar.dateComponents([.weekday, .hour, .minute], from: nextStart)
            XCTAssertEqual(nextComponents.weekday, 2) // Monday
            XCTAssertEqual(nextComponents.hour, 13)
            // Friday 20:00 to Monday 13:00 = 4h + 24h + 24h + 13h = 65 hours
            XCTAssertEqual(Int(untilNext), 65 * 3600)
        } else {
            XCTFail("Expected offPeak on Friday afternoon, got: \(status)")
        }
    }

    func testRegionalWindowsConversion() {
        let mondayNoon = makeDate(day: 14, hour: 14, minute: 0)
        let windows = engine.regionalWindows(for: mondayNoon)

        let utcWindow = windows.first { $0.regionCode == "UTC" }
        XCTAssertEqual(utcWindow?.windowString, "1:00 PM – 7:00 PM")

        let etWindow = windows.first { $0.regionCode == "ET" }
        XCTAssertEqual(etWindow?.windowString, "9:00 AM – 3:00 PM")

        let ptWindow = windows.first { $0.regionCode == "PT" }
        XCTAssertEqual(ptWindow?.windowString, "6:00 AM – 12:00 PM")

        let cetWindow = windows.first { $0.regionCode == "CET" }
        XCTAssertEqual(cetWindow?.windowString, "3:00 PM – 9:00 PM")
    }

    func testDayTimelineSlice() {
        let mondayMorning = makeDate(day: 14, hour: 13, minute: 0)
        let slice = engine.dayTimelineSlice(for: mondayMorning, targetTimezone: engine.utcTimeZone)

        XCTAssertTrue(slice.hasPeakToday)
        // 13:00 UTC / 24h = 13 / 24 = ~0.5416
        XCTAssertEqual(slice.peakStartFraction, 13.0 / 24.0, accuracy: 0.001)
        // 19:00 UTC / 24h = 19 / 24 = ~0.7916
        XCTAssertEqual(slice.peakEndFraction, 19.0 / 24.0, accuracy: 0.001)

        // Also test Eastern Time (EDT, UTC-4 in September)
        let etZone = TimeZone(identifier: "America/New_York")!
        let etSlice = engine.dayTimelineSlice(for: mondayMorning, targetTimezone: etZone)
        XCTAssertTrue(etSlice.hasPeakToday)
        // 9:00 AM EDT / 24h = 9 / 24 = 0.375
        XCTAssertEqual(etSlice.peakStartFraction, 9.0 / 24.0, accuracy: 0.001)
        // 3:00 PM EDT / 24h = 15 / 24 = 0.625
        XCTAssertEqual(etSlice.peakEndFraction, 15.0 / 24.0, accuracy: 0.001)
        XCTAssertEqual(etSlice.localStartString, "9:00 AM")
        XCTAssertEqual(etSlice.localEndString, "3:00 PM")
    }

    func testMenuBarTitleTransitions() {
        // Monday 12:30 UTC -> Approaching Peak (Starts in 30 mins)
        let approachingDate = makeDate(day: 14, hour: 12, minute: 30, second: 0)
        let approachingStatus = engine.currentStatus(at: approachingDate)
        XCTAssertEqual(approachingStatus.menuBarTitle, "PEAK SOON")

        // Monday 14:00 UTC -> Peak Active
        let peakDate = makeDate(day: 14, hour: 14, minute: 0, second: 0)
        let peakStatus = engine.currentStatus(at: peakDate)
        XCTAssertEqual(peakStatus.menuBarTitle, "PEAK")

        // Monday 20:00 UTC -> Off-Peak
        let offPeakDate = makeDate(day: 14, hour: 20, minute: 0, second: 0)
        let offPeakStatus = engine.currentStatus(at: offPeakDate)
        XCTAssertEqual(offPeakStatus.menuBarTitle, "OFF-PEAK")
    }
}
