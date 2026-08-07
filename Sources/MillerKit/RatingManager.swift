import Foundation
import SwiftUI
#if canImport(StoreKit)
import StoreKit   // \.requestReview lives here, not in SwiftUI
#endif

/// Decides *whether* to ask for a review. Deliberately does not ask: the view
/// layer owns the `@Environment(\.requestReview)` action, which is what fixes
/// the long-standing macOS bug where a menu-bar app with no key window resolved
/// no host and the prompt silently never appeared.
///
/// Three rules, all learned the hard way (see _shared/docs §4.4):
///
/// 1. **Attempts have a cooldown, they are not one-shot.** The old pattern set
///    `hasRequestedReview = true` forever the first time it called StoreKit —
///    but StoreKit shows the sheet at most ~3 times a year and may show nothing
///    at all. Burning the only attempt on a suppressed call means never asking
///    again for the life of the install.
/// 2. **Success paths only.** Never after an error, never on a paywall, never
///    on first launch. An interrupted user rates one star.
/// 3. **Earned, not timed.** Launches and days are necessary but not
///    sufficient; the user must have completed things the app is *for*.
@MainActor
public final class RatingManager: ObservableObject {

    public struct Gates: Sendable {
        public var minimumLaunches: Int
        public var minimumDays: Int
        public var minimumSignificantActions: Int
        /// How long before another attempt is allowed. Apple's own quota is
        /// ~3/year, so asking sooner than this is wasted regardless.
        public var cooldown: TimeInterval

        public init(
            minimumLaunches: Int = 10,
            minimumDays: Int = 7,
            minimumSignificantActions: Int = 3,
            cooldown: TimeInterval = 120 * 24 * 60 * 60
        ) {
            self.minimumLaunches = minimumLaunches
            self.minimumDays = minimumDays
            self.minimumSignificantActions = minimumSignificantActions
            self.cooldown = cooldown
        }

        /// Games earn a "job done" moment far faster than a file manager does.
        public static let game = Gates(minimumLaunches: 5, minimumDays: 2, minimumSignificantActions: 5)
        public static let utility = Gates()
    }

    private enum Key {
        static let launches = "millerkit.rating.launches"
        static let firstLaunch = "millerkit.rating.firstLaunchDate"
        static let actions = "millerkit.rating.significantActions"
        static let lastAttempt = "millerkit.rating.lastAttemptDate"
        static let attempts = "millerkit.rating.attemptCount"
        static let lastVersion = "millerkit.rating.lastPromptedVersion"
    }

    private let defaults: UserDefaults
    private let gates: Gates
    private let currentVersion: String

    public init(
        gates: Gates = .utility,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.gates = gates
        self.defaults = defaults
        self.currentVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    // MARK: - Recording

    /// Call once per cold launch, from the App's init or `.task`.
    public func recordLaunch() {
        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(Date(), forKey: Key.firstLaunch)
        }
        defaults.set(launches + 1, forKey: Key.launches)
    }

    /// Call when the user *completes* something the app exists to do — a sync
    /// that finished, a board cleared, an export written. Not taps, not screen
    /// views, and never anything that failed.
    public func recordSignificantAction(_ count: Int = 1) {
        defaults.set(significantActions + count, forKey: Key.actions)
    }

    // MARK: - Deciding

    public var launches: Int { defaults.integer(forKey: Key.launches) }
    public var significantActions: Int { defaults.integer(forKey: Key.actions) }
    public var attemptCount: Int { defaults.integer(forKey: Key.attempts) }
    public var firstLaunchDate: Date? { defaults.object(forKey: Key.firstLaunch) as? Date }
    public var lastAttemptDate: Date? { defaults.object(forKey: Key.lastAttempt) as? Date }

    public var daysSinceFirstLaunch: Int {
        guard let first = firstLaunchDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
    }

    /// Every gate, evaluated. Read-only — safe to call from a debug screen.
    public var shouldRequestReview: Bool {
        guard launches >= gates.minimumLaunches else { return false }
        guard daysSinceFirstLaunch >= gates.minimumDays else { return false }
        guard significantActions >= gates.minimumSignificantActions else { return false }
        // Never twice for the same version: if they didn't rate after the last
        // ask, a second ask on the same build is just nagging.
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }
        if let last = lastAttemptDate, Date().timeIntervalSince(last) < gates.cooldown { return false }
        return true
    }

    /// Records that an attempt was made. Call this *only* alongside actually
    /// invoking `requestReview` — it starts the cooldown, it does not claim the
    /// sheet was shown, because StoreKit never tells us that.
    public func recordAttempt() {
        defaults.set(Date(), forKey: Key.lastAttempt)
        defaults.set(attemptCount + 1, forKey: Key.attempts)
        defaults.set(currentVersion, forKey: Key.lastVersion)
    }

    /// For manual testing and the debug screen.
    public func resetForTesting() {
        [Key.launches, Key.firstLaunch, Key.actions, Key.lastAttempt, Key.attempts, Key.lastVersion]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    /// Human-readable gate state, for a debug row.
    public var debugSummary: String {
        "launches \(launches)/\(gates.minimumLaunches) · days \(daysSinceFirstLaunch)/\(gates.minimumDays) · actions \(significantActions)/\(gates.minimumSignificantActions) · attempts \(attemptCount) · eligible \(shouldRequestReview)"
    }
}

// MARK: - The view-side hook

// tvOS and watchOS have no review sheet — `\.requestReview` doesn't exist
// there. The manager above still compiles and counts on those platforms so a
// watch app can feed the same gate state the phone reads.
#if !os(tvOS) && !os(watchOS)
/// Attach to the view that represents a completed, successful outcome. When the
/// gates are met it asks StoreKit once, through the SwiftUI environment action
/// so the system resolves the host window itself.
///
/// ```swift
/// .requestReviewAfterSuccess(rating, when: syncDidFinish)
/// ```
public struct RequestReviewAfterSuccess: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject var manager: RatingManager
    let trigger: Bool

    public func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, newValue in
            guard newValue, manager.shouldRequestReview else { return }
            manager.recordAttempt()
            // A beat after the success UI lands: asking mid-animation reads as
            // an interruption of the thing the user just accomplished.
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                requestReview()
            }
        }
    }
}

public extension View {
    func requestReviewAfterSuccess(_ manager: RatingManager, when trigger: Bool) -> some View {
        modifier(RequestReviewAfterSuccess(manager: manager, trigger: trigger))
    }
}
#endif
