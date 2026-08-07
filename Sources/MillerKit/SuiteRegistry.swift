import Foundation

// Every app's identity in one place, so wiring a new app is one line at the
// call site instead of a fresh copy of the same four constants.
//
// Support addresses: `enter-space@wemiller.com` is a real, dedicated inbox and
// stays. Everything else routes to `blaine@wemiller.com` — the address already
// used across the suite. Give an app its own address here once that mailbox
// actually exists; a typo'd address fails silently as a bounce the user never
// sees, which is strictly worse than a shared inbox.
public extension SuiteApp {
    private static func page(_ slug: String) -> URL? {
        URL(string: "https://wemiller.com/apps/\(slug)/")
    }

    // ── Utilities ──────────────────────────────────────────────────────────
    static let enterSpace = SuiteApp(
        name: "Enter Space", supportEmail: "enter-space@wemiller.com",
        appStoreID: "6746350540", pageURL: page("enter-space")
    )
    static let haven = SuiteApp(
        name: "Haven", supportEmail: "blaine@wemiller.com",
        appStoreID: "6782147901", pageURL: page("haven")
    )
    static let ari = SuiteApp(
        name: "Ari Helper", supportEmail: "blaine@wemiller.com",
        appStoreID: "6480045555", pageURL: page("ari-helper")
    )
    static let sami = SuiteApp(
        name: "Sami", supportEmail: "blaine@wemiller.com",
        appStoreID: "6758907995", pageURL: page("sami")
    )
    static let panoOwl = SuiteApp(
        name: "Pano Owl", supportEmail: "blaine@wemiller.com",
        appStoreID: "1560273409", pageURL: page("pano-owl")
    )
    static let blip = SuiteApp(
        name: "Blip", supportEmail: "blaine@wemiller.com",
        appStoreID: "6762329495", pageURL: page("blip")
    )
    static let embr = SuiteApp(
        name: "Embr", supportEmail: "blaine@wemiller.com",
        appStoreID: "6727006089", pageURL: page("embr")
    )
    static let miSpeaks = SuiteApp(
        name: "Mi Speaks", supportEmail: "blaine@wemiller.com",
        appStoreID: "6451395651", pageURL: page("mi-speaks")
    )

    static let deepSi = SuiteApp(
        name: "DeepSi", supportEmail: "blaine@wemiller.com",
        appStoreID: "6449420511", pageURL: page("deepsi")
    )
    static let lumaEditor = SuiteApp(
        name: "Luma Editor", supportEmail: "blaine@wemiller.com",
        appStoreID: "6741085424", pageURL: page("luma-editor")
    )
    static let revela = SuiteApp(
        name: "Revela", supportEmail: "blaine@wemiller.com",
        appStoreID: "6791874917", pageURL: page("revela")
    )
    static let sightQuick = SuiteApp(
        name: "SightQuick", supportEmail: "blaine@wemiller.com",
        appStoreID: "6776991403", pageURL: page("sightquick")
    )

    /// Glint ships outside the App Store (direct Mac download), so it has no
    /// App Store ID — `writeReviewURL` is nil and LoveThisAppSection quietly
    /// drops the rate row, leaving just the link to the other apps.
    static let glint = SuiteApp(
        name: "Glint", supportEmail: "blaine@wemiller.com",
        appStoreID: nil, pageURL: page("glint")
    )

    // ── Games ──────────────────────────────────────────────────────────────
    // Games get the rating prompt and the "other apps" link, but not the
    // guided bug-report form: a stuck player writes "it's too hard", and the
    // reproduction fields just add friction to a rating they'd otherwise leave.
    static let tilebreak = SuiteApp(
        name: "Tilebreak", supportEmail: "blaine@wemiller.com",
        appStoreID: "6772609707", pageURL: page("tilebreak")
    )
    static let triAdd = SuiteApp(
        name: "Tri-Add", supportEmail: "blaine@wemiller.com",
        appStoreID: "860253889", pageURL: page("tri-add")
    )
    static let zap = SuiteApp(
        name: "Zap", supportEmail: "blaine@wemiller.com",
        appStoreID: "6776907420", pageURL: page("zap")
    )

    static let pinline = SuiteApp(
        name: "Pinline", supportEmail: "blaine@wemiller.com",
        appStoreID: "6772773442", pageURL: page("pinline")
    )
    static let ridgeshot = SuiteApp(
        name: "Ridgeshot", supportEmail: "blaine@wemiller.com",
        appStoreID: "6774483008", pageURL: page("ridgeshot")
    )
    static let wiseFlyer = SuiteApp(
        name: "Wise Flyer", supportEmail: "blaine@wemiller.com",
        appStoreID: "853900499", pageURL: page("wise-flyer")
    )
}
