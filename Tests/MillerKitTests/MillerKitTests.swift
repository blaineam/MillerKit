import XCTest
@testable import MillerKit

/// The two URLs every app kept getting wrong, and the one place they now come
/// from. Both bugs were invisible in code review and obvious to a user: a
/// privacy link that 404s, and a support address that bounces.
final class SuiteAppDefaultsTests: XCTestCase {

    func testPrivacyURLIsTheOneSuiteWidePolicy() {
        let app = SuiteApp(name: "Pinline", appStoreID: "6772773442")
        XCTAssertEqual(app.privacyURL.absoluteString, "https://wemiller.com/privacy/")
    }

    func testSupportEmailDefaultsToTheSharedInbox() {
        XCTAssertEqual(SuiteApp(name: "Anything").supportEmail, "apps@wemiller.com")
    }

    /// The regression that matters: not one app may quietly carry its own
    /// privacy path or its own mailbox again.
    func testEveryRegisteredAppUsesTheSharedSupportAddressAndPolicy() {
        for app in SuiteApp.all {
            XCTAssertEqual(app.supportEmail, SuiteApp.defaultSupportEmail,
                           "\(app.name) must send feedback to the shared inbox")
            XCTAssertEqual(app.privacyURL, SuiteApp.defaultPrivacyURL,
                           "\(app.name) must point at the one privacy policy")
        }
    }

    /// `pageURL` is the one thing that genuinely differs per app, so it must
    /// stay per-app and stay unique.
    func testAppPagesStayPerApp() {
        let pages = SuiteApp.all.compactMap(\.pageURL)
        XCTAssertEqual(pages.count, SuiteApp.all.count, "every app should have its own page")
        XCTAssertEqual(Set(pages).count, pages.count, "two apps share a page URL")
    }

    func testMailtoGoesToTheSharedInbox() throws {
        let url = try XCTUnwrap(Feedback.mailtoURL(app: .sami, kind: .bug))
        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:apps@wemiller.com?"))
    }
}

/// The "Version 1.0.0 in an app that shipped 1.3.0" bug. A package resource
/// bundle has its own, unrelated version; asking it for the app's version
/// fails silently and forever.
final class AppVersionTests: XCTestCase {

    /// The actual fix: handing the resolver a package bundle must never yield
    /// that package's version.
    func testPackageBundleNeverReportsItsOwnVersion() {
        let resolved = Bundle.appBundle(resolving: .module)
        XCTAssertNotEqual(resolved.bundleURL, Bundle.module.bundleURL,
                          "Bundle.module must resolve away to the app (or the main bundle)")
        let viaModule = DiagnosticContext(bundle: .module)
        let viaMain = DiagnosticContext(bundle: .main)
        XCTAssertEqual(viaModule.appVersion, viaMain.appVersion,
                       "the reported version must not depend on which bundle was passed in")
        XCTAssertEqual(viaModule.build, viaMain.build)

        // Belt and braces: whatever the package bundle claims for itself must
        // not be what a report shows, unless the app genuinely matches.
        let packageVersion = Bundle.module.infoDictionary?["CFBundleShortVersionString"] as? String
        if let packageVersion, packageVersion != viaMain.appVersion {
            XCTAssertNotEqual(viaModule.appVersion, packageVersion)
        }
    }

    func testMainBundleResolvesToItself() {
        XCTAssertEqual(Bundle.appBundle(resolving: .main).bundleURL, Bundle.appBundle.bundleURL)
    }

    /// A bundle sitting inside an `.app` resolves up to the app — the case
    /// that makes this work when it ships, which `swift test` can't otherwise
    /// reach (there is no `.app` in a package test run).
    func testAResourceBundleInsideAnAppResolvesToTheApp() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("millerkit-\(UUID().uuidString)")
        let appURL = root.appendingPathComponent("Sami.app")
        let resources = appURL.appendingPathComponent("Contents/Resources")
        let moduleURL = resources.appendingPathComponent("MillerKit_MillerKit.bundle")
        try FileManager.default.createDirectory(at: moduleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // A real app bundle needs an Info.plist for `Bundle(url:)` to load it.
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.wemiller.sami",
            "CFBundleShortVersionString": "1.3.0",
            "CFBundleVersion": "42",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: appURL.appendingPathComponent("Contents/Info.plist"))

        let packageBundle = try XCTUnwrap(Bundle(url: moduleURL))
        let resolved = Bundle.appBundle(resolving: packageBundle)
        XCTAssertEqual(resolved.bundleURL.standardizedFileURL.path, appURL.standardizedFileURL.path)
        XCTAssertEqual(AppVersion.short(bundle: resolved), "1.3.0")
        XCTAssertEqual(AppVersion.build(bundle: resolved), "42")
        XCTAssertEqual(AppVersion.display(bundle: resolved), "1.3.0 (42)")
        XCTAssertEqual(DiagnosticContext(bundle: packageBundle).appVersion, "1.3.0",
                       "a report composed from inside the package must carry the app's version")
    }

    /// Missing keys must read as an em dash, never as a plausible-looking
    /// "1.0.0" that nobody notices is wrong.
    func testMissingVersionIsVisiblyMissing() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("millerkit-\(UUID().uuidString)")
        let appURL = root.appendingPathComponent("Empty.app")
        try FileManager.default.createDirectory(
            at: appURL.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": "com.wemiller.empty"], format: .xml, options: 0)
        try data.write(to: appURL.appendingPathComponent("Contents/Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: appURL))
        XCTAssertEqual(AppVersion.short(bundle: bundle), "—")
        XCTAssertEqual(AppVersion.display(bundle: bundle), "—")
    }
}

/// The diagnostics attached to every report: enough to debug with, and
/// deliberately nothing that identifies the person sending it.
final class DiagnosticFooterTests: XCTestCase {

    func testFooterCarriesOnlyTheFiveAgreedFacts() {
        let footer = DiagnosticContext().reportFooter
        for expected in ["App version", "System", "Device", "Language"] {
            XCTAssertTrue(footer.contains(expected), "missing \(expected) from the diagnostic block")
        }
        // Nothing that identifies a person or a machine beyond its model.
        for forbidden in ["UUID", "identifierForVendor", "serial", "@", "token"] {
            XCTAssertFalse(footer.lowercased().contains(forbidden.lowercased()),
                           "diagnostics must not carry \(forbidden)")
        }
    }

    func testFooterTellsThePersonThatIsAllOfIt() {
        XCTAssertTrue(DiagnosticContext().reportFooter.contains("no identifiers"))
    }

    /// A bug report that doesn't ask what you expected produces a reply asking
    /// what you expected. These are the questions, and they must survive.
    func testBugTemplateAsksTheQuestionsThatSaveARoundTrip() {
        let body = Feedback.template(for: .bug, appName: "Sami")
        for question in ["What I was doing", "What I expected to happen",
                         "What actually happened", "Does it happen every time",
                         "When it started"] {
            XCTAssertTrue(body.contains(question), "bug template lost: \(question)")
        }
    }

    func testFeatureTemplateAsksWhatProblemItSolves() {
        let body = Feedback.template(for: .feature, appName: "Sami")
        XCTAssertTrue(body.contains("The problem this would solve for me"))
    }

    /// App-supplied context is the only channel for anything beyond the five
    /// facts, and it stays visible and deletable in the body.
    func testExtraContextAppearsAboveTheDiagnostics() throws {
        let url = try XCTUnwrap(Feedback.mailtoURL(app: .sami, kind: .bug, extraContext: ["mode": "batch"]))
        let decoded = try XCTUnwrap(url.absoluteString.removingPercentEncoding)
        let context = try XCTUnwrap(decoded.range(of: "mode: batch"))
        let footer = try XCTUnwrap(decoded.range(of: "App version"))
        XCTAssertTrue(context.lowerBound < footer.lowerBound)
    }
}

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

final class TranslationFeedbackTests: XCTestCase {
    let app = SuiteApp(name: "Enter Space", supportEmail: "enter-space@wemiller.com", appStoreID: "6746350540")

    /// The row must not appear for English speakers — they have nothing to
    /// report, and an untargeted ask is just noise in every settings screen.
    func testNotApplicableInEnglish() {
        XCTAssertFalse(TranslationFeedback.isApplicable(bundle: .main),
                       "test bundle runs in English, so the flow must stay hidden")
        XCTAssertTrue(TranslationFeedback.activeLocalization(bundle: .main).hasPrefix("en"))
    }

    func testMailtoCarriesTheAnswersAndTheLocale() throws {
        let url = try XCTUnwrap(TranslationFeedback.mailtoURL(
            app: app,
            screen: "Settings screen",
            currentWording: "Speicher & Sicherung",
            suggestedWording: "Speicher und Backup",
            notes: "The ampersand reads oddly here"
        ))
        let decoded = try XCTUnwrap(url.absoluteString.removingPercentEncoding)
        XCTAssertTrue(decoded.contains("Settings screen"))
        XCTAssertTrue(decoded.contains("Speicher & Sicherung"))
        XCTAssertTrue(decoded.contains("Speicher und Backup"))
        XCTAssertTrue(decoded.contains("The ampersand reads oddly here"))
        // The confirmed prerequisites travel with the report, so the reply can
        // assume a conversation is welcome.
        XCTAssertTrue(decoded.contains("happy to go back and forth"))
    }

    /// Non-Latin and ampersand-bearing wording is exactly what this flow
    /// carries, so the query must survive it.
    func testNonLatinWordingSurvivesEncoding() throws {
        let url = try XCTUnwrap(TranslationFeedback.mailtoURL(
            app: app, screen: "ホーム画面", currentWording: "保存 & 共有",
            suggestedWording: "保存と共有", notes: ""
        ))
        let query = try XCTUnwrap(url.query)
        XCTAssertEqual(query.components(separatedBy: "&").count, 2, "only the subject/body separator may be a bare &")
        let decoded = try XCTUnwrap(url.absoluteString.removingPercentEncoding)
        XCTAssertTrue(decoded.contains("保存と共有"))
    }

    func testOptionalNotesAreOmittedWhenBlank() throws {
        let url = try XCTUnwrap(TranslationFeedback.mailtoURL(
            app: app, screen: "A", currentWording: "B", suggestedWording: "C", notes: "   "
        ))
        let decoded = try XCTUnwrap(url.absoluteString.removingPercentEncoding)
        XCTAssertFalse(decoded.contains("Why / anything else:"))
    }
}
