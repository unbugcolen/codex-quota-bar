import XCTest
@testable import CodexQuotaBar

final class QuotaSnapshotTests: XCTestCase {
    func testWeeklyOnlyResponseDoesNotPopulateFiveHourQuota() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":11,"windowDurationMins":10080,"resetsAt":1792475808},"secondary":null},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":11,"windowDurationMins":10080,"resetsAt":1792475808},"secondary":null}}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertNil(snapshot.fiveHour.remainingPercent)
        XCTAssertNil(snapshot.fiveHour.resetDate)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 89)
        XCTAssertEqual(snapshot.weekly.resetDate, Date(timeIntervalSince1970: 1792475808))
    }

    func testFiveHourOnlyResponseDoesNotPopulateWeeklyQuota() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":null}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 80)
        XCTAssertNil(snapshot.weekly.remainingPercent)
    }

    func testWindowDurationTakesPriorityOverPrimarySecondaryOrder() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":30,"windowDurationMins":10080},"secondary":{"usedPercent":10,"windowDurationMins":300}}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 90)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 70)
    }

    func testMissingDurationsPreserveLegacyWindowOrder() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":10},"secondary":{"usedPercent":30}}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 90)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 70)
    }

    func testUnrelatedWindowIsNotLabeledAsFiveHoursOrWeekly() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":60},"secondary":null}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertNil(snapshot.fiveHour.remainingPercent)
        XCTAssertNil(snapshot.weekly.remainingPercent)
    }

    func testCodexBucketTakesPriorityOverLegacyAndOtherBuckets() throws {
        let response = try decode(#"""
        {"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":11,"windowDurationMins":10080}},"other":{"primary":{"usedPercent":90,"windowDurationMins":300}}}}
        """#)
        let snapshot = QuotaSnapshot(rateLimits: response.codexRateLimits)

        XCTAssertNil(snapshot.fiveHour.remainingPercent)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 89)
    }

    private func decode(_ json: String) throws -> AppServerRateLimitsResponse {
        try JSONDecoder().decode(AppServerRateLimitsResponse.self, from: Data(json.utf8))
    }
}
