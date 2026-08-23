import Foundation
#if os(macOS)
import Security
#endif

/// How this build reached the user — the gate for donation/"support the developer" links,
/// which are Guideline 3.1.1 rejection bait in anything Apple distributes.
///
/// v2 (field-hardened): the receipt heuristic mis-called macOS TestFlight builds "direct"
/// when the receipt file wasn't materialized at launch, and the funding row leaked into a
/// TF build. The rules are now structural, not circumstantial:
///   • iOS-family platforms have NO direct-distribution channel — funding links never show.
///   • macOS decides by CODE SIGNATURE: Apple-signed (Mac App Store / TestFlight leaf
///     certs) hides; Developer ID / development-signed / unsigned is genuinely direct.
///     A present store receipt also hides, as a fast path.
public enum Distribution {
    case appStore
    case testFlight
    case direct

    public static let current: Distribution = {
        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        switch Bundle.main.appStoreReceiptURL?.lastPathComponent {
        case "sandboxReceipt": return .testFlight
        default: return .appStore   // store, or a dev build — either way, not "direct distribution"
        }
        #elseif os(macOS)
        if let receipt = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receipt.path) {
            return receipt.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
        }
        switch macLeafCertificateCommonName() {
        case let cn? where cn.hasPrefix("Apple Mac OS Application Signing"): return .appStore
        case let cn? where cn.localizedCaseInsensitiveContains("TestFlight"): return .testFlight
        default: return .direct     // Developer ID, Apple Development, ad-hoc, unsigned
        }
        #else
        return .direct
        #endif
    }()

    /// Whether donation-style external funding links belong in this build.
    /// Anything Apple distributes (or could have): no. Only genuinely direct macOS
    /// builds (Developer ID / dev-signed): yes.
    public static var allowsExternalFundingLinks: Bool {
        #if os(macOS)
        return current == .direct
        #else
        return false
        #endif
    }

    #if os(macOS)
    /// Common name of our own leaf signing certificate, or nil.
    private static func macLeafCertificateCommonName() -> String? {
        var codeRef: SecCode?
        guard SecCodeCopySelf([], &codeRef) == errSecSuccess, let code = codeRef else { return nil }
        var staticRef: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticRef) == errSecSuccess, let staticCode = staticRef else { return nil }
        var infoRef: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &infoRef) == errSecSuccess,
              let info = infoRef as? [String: Any],
              let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certs.first else { return nil }
        var cn: CFString?
        SecCertificateCopyCommonName(leaf, &cn)
        return cn as String?
    }
    #endif
}
