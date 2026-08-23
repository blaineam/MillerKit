import Foundation

/// How this build reached the user — decided from the App Store receipt, the one signal
/// that exists at runtime without entitlements or network.
///
/// Why it exists: donation/"support the developer" links that route around In-App
/// Purchase are Guideline 3.1.1 bait in App Store review (the US external-link ruling
/// notwithstanding, the rest of the world's storefronts still enforce it, and review is
/// inconsistent even where it's now allowed). The suite's free apps are funded by
/// donations from the DIRECT downloads — so the support row shows there, and never in a
/// build Apple distributed. One rule, applied automatically, no per-app flags to forget.
public enum Distribution {
    /// Downloaded from the App Store (or a TestFlight build of a store app).
    case appStore
    /// TestFlight specifically (a store-adjacent context — treated like the store).
    case testFlight
    /// Direct download, Homebrew, dev build — anything without a store receipt.
    case direct

    public static let current: Distribution = {
        #if os(macOS) || os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        guard let receipt = Bundle.main.appStoreReceiptURL else { return .direct }
        switch receipt.lastPathComponent {
        case "receipt": return .appStore
        case "sandboxReceipt": return .testFlight
        default:
            // Mac App Store receipts live at .../_MASReceipt/receipt — covered above.
            // Anything else with a receipt URL that actually exists is store-adjacent.
            return FileManager.default.fileExists(atPath: receipt.path) ? .appStore : .direct
        }
        #else
        return .direct
        #endif
    }()

    /// Whether donation-style external funding links belong in this build.
    /// Store + TestFlight builds: no (3.1.1). Everything else: yes.
    public static var allowsExternalFundingLinks: Bool {
        switch current {
        case .appStore, .testFlight: return false
        case .direct: return true
        }
    }
}
