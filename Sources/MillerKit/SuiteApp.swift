import Foundation

/// Identity for one app in the suite. Everything MillerKit shows — the support
/// email, the rating prompt, the "more apps" link — is driven from one of these,
/// declared once per app and passed in through the environment.
public struct SuiteApp: Sendable, Hashable {
    /// Display name, as the user sees it. Never localized — it's a brand.
    public let name: String
    /// Where feedback goes. Per-app so mail rules can sort it.
    public let supportEmail: String
    /// Numeric App Store ID, for the "write a review" deep link.
    public let appStoreID: String?
    /// The app's own page on the portfolio.
    public let pageURL: URL?
    /// Where "see my other apps" goes.
    public let portfolioURL: URL

    public init(
        name: String,
        supportEmail: String,
        appStoreID: String? = nil,
        pageURL: URL? = nil,
        portfolioURL: URL = URL(string: "https://wemiller.com/apps/")!
    ) {
        self.name = name
        self.supportEmail = supportEmail
        self.appStoreID = appStoreID
        self.pageURL = pageURL
        self.portfolioURL = portfolioURL
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

    public init(bundle: Bundle = .main) {
        let info = bundle.infoDictionary
        appVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        build = info?["CFBundleVersion"] as? String ?? "?"

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

    /// The block appended to every report. Plain text, labelled, and explicitly
    /// explained — people delete anything that looks like a tracking payload.
    public var reportFooter: String {
        """
        ——————————————
        \(String(localized: "These details help me diagnose it — please leave them in:", bundle: .module, comment: "Explains the diagnostic block at the bottom of a feedback email"))
        \(name(for: "app")): \(appVersion) (\(build))
        \(name(for: "system")): \(system)
        \(name(for: "device")): \(device)
        \(name(for: "language")): \(locale)
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
