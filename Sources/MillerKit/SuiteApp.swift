import Foundation

/// Identity for one app in the suite. Everything MillerKit shows — the support
/// email, the rating prompt, the "more apps" link — is driven from one of these,
/// declared once per app and passed in through the environment.
public struct SuiteApp: Sendable, Hashable {
    /// One support address for the whole suite. Per-app addresses were a
    /// standing source of dead ends: a mailbox that was never actually created
    /// bounces silently, and the sender never learns their report went nowhere.
    /// One real inbox, sorted on the subject line (which already carries the
    /// app name), beats nineteen aspirational ones.
    public static let defaultSupportEmail = "apps@wemiller.com"

    /// There is exactly one privacy policy and it covers every app. Apps had
    /// been composing a per-app path — `…/apps/pinline/privacy/` — which does
    /// not exist and 404s. Hence a constant rather than a convention.
    public static let defaultPrivacyURL = URL(string: "https://wemiller.com/privacy/")!

    /// Where "see my other apps" goes.
    public static let defaultPortfolioURL = URL(string: "https://wemiller.com/apps/")!

    /// Where "support future development" goes — the one page that lists every
    /// way to fund the work (GitHub Sponsors, Ko-fi, a one-time tip). The page
    /// is the link target, not the individual services, so adding or dropping
    /// a service is a website edit rather than an app release.
    public static let defaultSupportURL = URL(string: "https://wemiller.com/support/")!

    /// Display name, as the user sees it. Never localized — it's a brand.
    public let name: String
    /// Where feedback goes. Suite-wide; see `defaultSupportEmail`.
    public let supportEmail: String
    /// Numeric App Store ID, for the "write a review" deep link.
    public let appStoreID: String?
    /// The app's own page on the portfolio — the one genuinely per-app URL.
    public let pageURL: URL?
    /// The privacy policy. Suite-wide; see `defaultPrivacyURL`.
    public let privacyURL: URL
    /// Where "see my other apps" goes.
    public let portfolioURL: URL
    /// Where "support future development" goes, or nil to show no such row.
    /// Opt-in on purpose: it belongs in the FREE apps (Haven, Blip, Glint —
    /// donation-funded, no ads, no purchases), not in an app the user already
    /// paid for, and every extra external funding link in an App Store build is
    /// something App Review can read as a purchase mechanism (Guideline 3.1.1).
    public let supportURL: URL?

    public init(
        name: String,
        supportEmail: String = SuiteApp.defaultSupportEmail,
        appStoreID: String? = nil,
        pageURL: URL? = nil,
        privacyURL: URL = SuiteApp.defaultPrivacyURL,
        portfolioURL: URL = SuiteApp.defaultPortfolioURL,
        supportURL: URL? = nil
    ) {
        self.name = name
        self.supportEmail = supportEmail
        self.appStoreID = appStoreID
        self.pageURL = pageURL
        self.privacyURL = privacyURL
        self.portfolioURL = portfolioURL
        self.supportURL = supportURL
    }

    /// Deep link that opens the App Store review sheet directly. This is the
    /// only honest way to ask for a review on demand: `requestReview` is
    /// rate-limited by Apple and may show nothing at all, so a button labelled
    /// "Rate the app" must go somewhere the user can actually type.
    public var writeReviewURL: URL? {
        guard let appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    public var appStoreURL: URL? {
        guard let appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }
}

/// Build/runtime facts worth putting in every bug report. Collected here so the
/// report format is identical across apps and can't drift.
public struct DiagnosticContext: Sendable {
    public let appVersion: String
    public let build: String
    public let system: String
    public let device: String
    public let locale: String

    /// - Parameter bundle: any bundle belonging to the running app. It is
    ///   resolved through `Bundle.appBundle(resolving:)` first, so handing this
    ///   a package resource bundle (`Bundle.module`) still reports the *app's*
    ///   version rather than the package's — the bug behind every "Version
    ///   1.0.0" in an app that shipped 1.3.0.
    public init(bundle: Bundle = .main) {
        let app = Bundle.appBundle(resolving: bundle)
        appVersion = AppVersion.short(bundle: app)
        build = AppVersion.build(bundle: app)

        #if os(macOS)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        system = "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        device = Self.hardwareModel() ?? "Mac"
        #elseif os(watchOS)
        system = "watchOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
        device = "Apple Watch"
        #elseif os(tvOS)
        system = "tvOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
        device = "Apple TV"
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        system = "iOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        device = Self.hardwareModel() ?? "iPhone/iPad"
        #endif

        locale = Locale.current.identifier
    }

    /// `iPhone17,1` style identifier — the single most useful field in a bug
    /// report and the one users can never find to tell you.
    static func hardwareModel() -> String? {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var chars = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &chars, &size, nil, 0)
        return String(cString: chars)
        #else
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        let id = mirror.children.reduce(into: "") { acc, el in
            guard let value = el.value as? Int8, value != 0 else { return }
            acc.append(Character(UnicodeScalar(UInt8(value))))
        }
        return id.isEmpty ? nil : id
        #endif
    }

    /// The block appended to every report. Plain text, labelled, legible, and
    /// short enough to read in full before hitting send — people delete
    /// anything that looks like a tracking payload, and they're right to.
    ///
    /// Five lines, and deliberately no more: version, build, OS, device model,
    /// language. No identifiers, no account, no location, no logs the user
    /// hasn't seen. Anything else has to come from the app as `extraContext`,
    /// which the app author chose and the user can read and delete.
    public var reportFooter: String {
        """
        ——————————————
        \(String(localized: "These details help me diagnose it — please leave them in:", bundle: .module, comment: "Explains the diagnostic block at the bottom of a feedback email"))
        \(name(for: "app")): \(appVersion) (\(build))
        \(name(for: "system")): \(system)
        \(name(for: "device")): \(device)
        \(name(for: "language")): \(locale)
        \(String(localized: "That's everything attached — no identifiers, no location, no logs. Delete any line you'd rather not send.", bundle: .module, comment: "Reassurance under the diagnostic block in a feedback email"))
        """
    }

    private func name(for key: String) -> String {
        switch key {
        case "app": return String(localized: "App version", bundle: .module, comment: "Label in a bug report's diagnostic block")
        case "system": return String(localized: "System", bundle: .module, comment: "Label in a bug report's diagnostic block")
        case "device": return String(localized: "Device", bundle: .module, comment: "Label in a bug report's diagnostic block")
        default: return String(localized: "Language", bundle: .module, comment: "Label in a bug report's diagnostic block")
        }
    }
}
