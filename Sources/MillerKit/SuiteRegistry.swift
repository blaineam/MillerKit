import Foundation

// Every app's identity in one place, so wiring a new app is one line at the
// call site instead of a fresh copy of the same four constants.
//
// Support address and privacy policy are deliberately *not* listed per app:
// every entry takes `SuiteApp.defaultSupportEmail` (apps@wemiller.com) and
// `SuiteApp.defaultPrivacyURL` (https://wemiller.com/privacy/). Both were
// per-app once and both drifted — into mailboxes that were never created and
// bounce silently, and into `/apps/<slug>/privacy/` paths that 404. The one
// genuinely per-app URL left is `pageURL`.
public extension SuiteApp {
    private static func page(_ slug: String) -> URL? {
        URL(string: "https://wemiller.com/apps/\(slug)/")
    }

    // ── Utilities ──────────────────────────────────────────────────────────
    static let enterSpace = SuiteApp(
        name: "Enter Space", appStoreID: "6746350540", pageURL: page("enter-space")
    )
    /// Free, donation-funded — the support row is on (see `SuiteApp.supportURL`).
    static let haven = SuiteApp(
        name: "Haven", appStoreID: "6782147901", pageURL: page("haven"),
        supportURL: SuiteApp.defaultSupportURL
    )
    static let ari = SuiteApp(
        name: "Ari Helper", appStoreID: "6480045555", pageURL: page("ari-helper")
    )
    static let sami = SuiteApp(
        name: "Sami", appStoreID: "6758907995", pageURL: page("sami")
    )
    static let panoOwl = SuiteApp(
        name: "Pano Owl", appStoreID: "1560273409", pageURL: page("pano-owl")
    )
    /// Free (direct download, Homebrew and the Mac App Store alike) — support row on.
    static let blip = SuiteApp(
        name: "Blip", appStoreID: "6762329495", pageURL: page("blip"),
        supportURL: SuiteApp.defaultSupportURL
    )
    static let embr = SuiteApp(
        name: "Embr", appStoreID: "6727006089", pageURL: page("embr")
    )
    static let miSpeaks = SuiteApp(
        name: "Mi Speaks", appStoreID: "6451395651", pageURL: page("mi-speaks")
    )

    static let deepSi = SuiteApp(
        name: "DeepSi", appStoreID: "6449420511", pageURL: page("deepsi")
    )
    static let lumaEditor = SuiteApp(
        name: "Luma Editor", appStoreID: "6741085424", pageURL: page("luma-editor")
    )
    static let revela = SuiteApp(
        name: "Revela", appStoreID: "6791874917", pageURL: page("revela")
    )
    static let sightQuick = SuiteApp(
        name: "SightQuick", appStoreID: "6776991403", pageURL: page("sightquick")
    )

    /// Glint ships outside the App Store (direct Mac download), so it has no
    /// App Store ID — `writeReviewURL` is nil and LoveThisAppSection quietly
    /// drops the rate row, leaving just the link to the other apps.
    static let glint = SuiteApp(
        name: "Glint", appStoreID: nil, pageURL: page("glint"),
        supportURL: SuiteApp.defaultSupportURL
    )

    // ── Games ──────────────────────────────────────────────────────────────
    // Games get the rating prompt and the "other apps" link, but not the
    // guided bug-report form: a stuck player writes "it's too hard", and the
    // reproduction fields just add friction to a rating they'd otherwise leave.
    static let tilebreak = SuiteApp(
        name: "Tilebreak", appStoreID: "6772609707", pageURL: page("tilebreak")
    )
    static let triAdd = SuiteApp(
        name: "Tri-Add", appStoreID: "860253889", pageURL: page("tri-add")
    )
    static let zap = SuiteApp(
        name: "Zap", appStoreID: "6776907420", pageURL: page("zap")
    )
    static let kern = SuiteApp(
        name: "Kern", appStoreID: "6806896106", pageURL: page("kern")
    )

    static let pinline = SuiteApp(
        name: "Pinline", appStoreID: "6772773442", pageURL: page("pinline")
    )
    static let ridgeshot = SuiteApp(
        name: "Ridgeshot", appStoreID: "6774483008", pageURL: page("ridgeshot")
    )
    static let wiseFlyer = SuiteApp(
        name: "Wise Flyer", appStoreID: "853900499", pageURL: page("wise-flyer")
    )

    /// Every registered app. Exists so a test can assert across the whole
    /// suite — that no app has drifted back to its own support address or its
    /// own privacy path — rather than trusting nineteen call sites.
    /// Add new apps here as well as above.
    static let all: [SuiteApp] = [
        .enterSpace, .haven, .ari, .sami, .panoOwl, .blip, .embr, .miSpeaks,
        .deepSi, .lumaEditor, .revela, .sightQuick, .glint,
        .tilebreak, .triAdd, .zap, .kern, .pinline, .ridgeshot, .wiseFlyer,
    ]
}
