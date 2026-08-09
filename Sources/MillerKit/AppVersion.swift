import Foundation

// The version an app shows in About has to come from the app's own Info.plist,
// and there is exactly one reliable way to get there. Every app that got this
// wrong got it wrong in one of two ways:
//
// 1. It hard-coded the string, and the string rotted the first time the app
//    shipped an update. (Sami's About row read "Version 1.0.0" at 1.3.0.)
// 2. It asked a bundle that wasn't the app. Code living in a SwiftPM target
//    that reaches for `Bundle.module` gets the *package's* resource bundle,
//    whose CFBundleShortVersionString is the package's own — usually "1.0" or
//    missing entirely. Nothing crashes; it just quietly reports the wrong
//    number forever.
//
// `Bundle.appBundle` exists so neither is possible: it resolves whatever it is
// handed up to the enclosing `.app`, and `AppVersion` reads only from that.

public extension Bundle {
    /// The bundle of the running app, resolved from anywhere inside it.
    ///
    /// A package resource bundle and a framework both live *inside* the
    /// `.app` — so walking up the path from either lands on the app. Under
    /// `swift test` (or in a command-line tool) there is no `.app` at all;
    /// there the main bundle is the only honest answer, and it is what the
    /// host app will be at runtime.
    static func appBundle(resolving bundle: Bundle = .main) -> Bundle {
        if let app = enclosingAppBundle(of: bundle.bundleURL) { return app }
        // Not inside an app: never report a package bundle's own version.
        // Fall back to the main bundle, resolving it the same way.
        if bundle !== Bundle.main, let app = enclosingAppBundle(of: Bundle.main.bundleURL) { return app }
        return .main
    }

    /// Convenience for the common case.
    static var appBundle: Bundle { appBundle(resolving: .main) }

    /// The `.app` that `url` is, or is contained in — nil if there isn't one.
    internal static func enclosingAppBundle(of url: URL) -> Bundle? {
        var candidate = url.standardizedFileURL
        // A resource bundle sits several levels down:
        //   MyApp.app/Contents/Resources/MillerKit_MillerKit.bundle
        while candidate.pathComponents.count > 1 {
            if candidate.pathExtension == "app" {
                return Bundle(url: candidate)
            }
            candidate = candidate.deletingLastPathComponent()
        }
        return nil
    }
}

/// The app's marketing version and build, read from the app bundle and nowhere
/// else. Use this instead of hand-rolling an `infoDictionary` lookup, and never
/// type a version number into a view.
public enum AppVersion {
    /// `CFBundleShortVersionString` — the number users and the App Store mean
    /// by "version". 1.3.0, not 342.
    public static func short(bundle: Bundle = .appBundle) -> String {
        value(for: "CFBundleShortVersionString", in: bundle) ?? "—"
    }

    /// `CFBundleVersion` — the build number.
    public static func build(bundle: Bundle = .appBundle) -> String {
        value(for: "CFBundleVersion", in: bundle) ?? "—"
    }

    /// `1.3.0 (342)`, or just `1.3.0` when the build number adds nothing.
    public static func display(bundle: Bundle = .appBundle) -> String {
        let short = Self.short(bundle: bundle)
        let build = Self.build(bundle: bundle)
        guard build != "—", build != short else { return short }
        return "\(short) (\(build))"
    }

    private static func value(for key: String, in bundle: Bundle) -> String? {
        // `object(forInfoDictionaryKey:)` is the localized-aware lookup and
        // falls back to infoDictionary; prefer it, but keep the raw read as a
        // backstop for bundles built without a localized Info.plist.
        let raw = bundle.object(forInfoDictionaryKey: key) as? String
            ?? bundle.infoDictionary?[key] as? String
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return raw
    }
}
