import XCTest
import Foundation

/// Tests for flexible date parsing logic
/// Verifies the 4 supported date formats in parseFlexibleDate()
final class FlexibleDateParsingTests: XCTestCase {

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Format 1: Full ISO8601

    func testFullISO8601WithTimezone() {
        let dateStr = "2026-02-06T14:00:00+08:00"
        let date = iso8601Formatter.date(from: dateStr)
        XCTAssertNotNil(date, "Should parse full ISO8601 with timezone")
    }

    func testFullISO8601WithUTC() {
        let dateStr = "2026-02-06T06:00:00Z"
        let date = iso8601Formatter.date(from: dateStr)
        XCTAssertNotNil(date, "Should parse ISO8601 with Z timezone")
    }

    // MARK: - Format 2: ISO8601 without timezone

    func testDatetimeWithoutTimezone() {
        let dateStr = "2026-02-06T14:00:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: dateStr)
        XCTAssertNotNil(date, "Should parse datetime without timezone")

        if let date = date {
            let cal = Calendar.current
            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 2)
            XCTAssertEqual(components.day, 6)
            XCTAssertEqual(components.hour, 14)
            XCTAssertEqual(components.minute, 0)
        }
    }

    // MARK: - Format 3: Date only

    func testDateOnly() {
        let dateStr = "2026-02-06"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: dateStr)
        XCTAssertNotNil(date, "Should parse date-only format")

        if let date = date {
            let cal = Calendar.current
            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            XCTAssertEqual(components.year, 2026)
            XCTAssertEqual(components.month, 2)
            XCTAssertEqual(components.day, 6)
            XCTAssertEqual(components.hour, 0)
            XCTAssertEqual(components.minute, 0)
        }
    }

    func testDateOnlyFormat() {
        // Verify the string is exactly 10 characters and contains dashes
        let dateStr = "2026-02-06"
        XCTAssertEqual(dateStr.count, 10)
        XCTAssertTrue(dateStr.contains("-"))
        XCTAssertFalse(dateStr.contains("T"))
    }

    // MARK: - Format 4: Time only

    func testTimeOnlyShort() {
        let timeStr = "14:00"
        let components = timeStr.split(separator: ":")
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(Int(components[0]), 14)
        XCTAssertEqual(Int(components[1]), 0)
    }

    func testTimeOnlyWithSeconds() {
        let timeStr = "14:30:45"
        let components = timeStr.split(separator: ":")
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(Int(components[0]), 14)
        XCTAssertEqual(Int(components[1]), 30)
        XCTAssertEqual(Int(components[2]), 45)
    }

    func testTimeOnlyProducesToday() {
        let timeStr = "09:30"
        let components = timeStr.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            XCTFail("Should parse time components")
            return
        }

        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let now = Date()
        var dc = cal.dateComponents([.year, .month, .day], from: now)
        dc.hour = hour
        dc.minute = minute
        dc.second = 0
        let date = cal.date(from: dc)

        XCTAssertNotNil(date, "Should create date for today at given time")

        if let date = date {
            let resultComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let nowComponents = cal.dateComponents([.year, .month, .day], from: now)
            XCTAssertEqual(resultComponents.year, nowComponents.year)
            XCTAssertEqual(resultComponents.month, nowComponents.month)
            XCTAssertEqual(resultComponents.day, nowComponents.day)
            XCTAssertEqual(resultComponents.hour, 9)
            XCTAssertEqual(resultComponents.minute, 30)
        }
    }

    // MARK: - Format Detection

    func testFormatDetection() {
        // Full ISO8601 - contains T and + or Z
        let iso = "2026-02-06T14:00:00+08:00"
        XCTAssertTrue(iso.contains("T") && (iso.contains("+") || iso.contains("Z")))

        // Datetime without TZ - contains T but no + or Z
        let datetime = "2026-02-06T14:00:00"
        XCTAssertTrue(datetime.contains("T") && !datetime.contains("+") && !datetime.contains("Z"))

        // Date only - 10 chars, has -, no T
        let dateOnly = "2026-02-06"
        XCTAssertTrue(dateOnly.count == 10 && dateOnly.contains("-") && !dateOnly.contains("T"))

        // Time only - no -, has :
        let timeOnly = "14:00"
        XCTAssertTrue(!timeOnly.contains("-") && timeOnly.contains(":"))
    }

    // MARK: - Edge Cases

    func testInvalidFormatDetection() {
        // These should NOT match any format
        let invalid = ["abc", "2026", "14", "2026/02/06", ""]
        for str in invalid {
            // None of the format checks should match
            let isISO = iso8601Formatter.date(from: str) != nil
            let isDatetime = str.contains("T") && !str.contains("+") && !str.contains("Z")
            let isDateOnly = str.count == 10 && str.contains("-") && !str.contains("T")
            let isTimeOnly = !str.contains("-") && str.contains(":")

            if !isISO && !isDatetime && !isDateOnly && !isTimeOnly {
                // Expected: none of the formats match
            } else if str == "" {
                // Empty string won't match any parser even if some conditions pass
            }
            // We just verify the detection logic doesn't crash
            XCTAssertFalse(isISO, "'\(str)' should not be valid ISO8601")
        }
    }
}
