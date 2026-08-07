import XCTest
@testable import MillerKit

final class FeedbackTests: XCTestCase {
    let app = SuiteApp(name: "Enter Space", supportEmail: "enter-space@wemiller.com", appStoreID: "6746350540")

    func testMailtoURLIsWellFormed() throws {
        let url = try XCTUnwrap(Feedback.mailtoURL(app: app, kind: .bug))
        XCTAssertEqual(url.scheme, "mailto")
        let s = url.absoluteString
        XCTAssertTrue(s.hasPrefix("mailto:enter-space@wemiller.com?"))
        XCTAssertTrue(s.contains("subject="))
        XCTAssertTrue(s.contains("body="))
    }

    /// The encoding bug this guards: an unescaped `&` or `?` in the body
    /// silently truncates the email at that character.
    func testSubDelimitersAreEscaped() throws {
        let url = try XCTUnwrap(Feedback.mailtoURL(app: app, kind: .bug, extraContext: ["remote": "S3 & Backblaze?"]))
        let query = try XCTUnwrap(url.query)
        // Exactly one separator: the one between subject and body.
        XCTAssertEqual(query.components(separatedBy: "&").count, 2)
    }

    func testExtraContextIsIncludedAndSorted() throws {
        let url = try XCTUnwrap(Feedback.mailtoURL(app: app, kind: .bug, extraContext: ["zebra": "1", "alpha": "2"]))
        let decoded = try XCTUnwrap(url.absoluteString.removingPercentEncoding)
        let a = try XCTUnwrap(decoded.range(of: "alpha: 2"))
        let z = try XCTUnwrap(decoded.range(of: "zebra: 1"))
        XCTAssertTrue(a.lowerBound < z.lowerBound, "context lines should be stable-sorted")
    }

    func testWriteReviewURLUsesActionParameter() throws {
        let url = try XCTUnwrap(app.writeReviewURL)
        XCTAssertTrue(url.absoluteString.hasSuffix("?action=write-review"))
    }

    func testNoAppStoreIDMeansNoReviewURL() {
        let noID = SuiteApp(name: "Beta", supportEmail: "x@y.z")
        XCTAssertNil(noID.writeReviewURL)
    }
}

@MainActor
final class RatingManagerTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "millerkit.tests.\(UUID().uuidString)")
    }

    private func manager(_ gates: RatingManager.Gates = .init(minimumLaunches: 3, minimumDays: 0, minimumSignificantActions: 2)) -> RatingManager {
        RatingManager(gates: gates, defaults: defaults)
    }

    func testGatesBlockUntilAllAreMet() {
        let m = manager()
        XCTAssertFalse(m.shouldRequestReview, "fresh install must never be asked")
        m.recordLaunch(); m.recordLaunch(); m.recordLaunch()
        XCTAssertFalse(m.shouldRequestReview, "launches alone are not enough")
        m.recordSignificantAction()
        XCTAssertFalse(m.shouldRequestReview, "one action short")
        m.recordSignificantAction()
        XCTAssertTrue(m.shouldRequestReview)
    }

    /// The bug in the copied pattern: a permanent one-shot flag meant a
    /// suppressed StoreKit call burned the only chance forever.
    func testAttemptStartsCooldownRatherThanPermanentlyDisabling() {
        let m = manager()
        m.recordLaunch(); m.recordLaunch(); m.recordLaunch()
        m.recordSignificantAction(2)
        XCTAssertTrue(m.shouldRequestReview)
        m.recordAttempt()
        XCTAssertFalse(m.shouldRequestReview, "cooldown should suppress an immediate re-ask")
        XCTAssertEqual(m.attemptCount, 1)

        // Past the cooldown, and on a later version, it becomes eligible again.
        defaults.set(Date().addingTimeInterval(-200 * 24 * 60 * 60), forKey: "millerkit.rating.lastAttemptDate")
        defaults.set("0.0.0-old", forKey: "millerkit.rating.lastPromptedVersion")
        XCTAssertTrue(m.shouldRequestReview, "an old attempt must not disable the prompt for life")
    }

    func testSameVersionIsNeverAskedTwice() {
        let m = manager()
        m.recordLaunch(); m.recordLaunch(); m.recordLaunch()
        m.recordSignificantAction(2)
        m.recordAttempt()
        defaults.set(Date().addingTimeInterval(-200 * 24 * 60 * 60), forKey: "millerkit.rating.lastAttemptDate")
        XCTAssertFalse(m.shouldRequestReview, "cooldown elapsed but the version hasn't changed")
    }

    func testResetForTestingClearsEverything() {
        let m = manager()
        m.recordLaunch(); m.recordSignificantAction(5); m.recordAttempt()
        m.resetForTesting()
        XCTAssertEqual(m.launches, 0)
        XCTAssertEqual(m.significantActions, 0)
        XCTAssertEqual(m.attemptCount, 0)
    }
}
