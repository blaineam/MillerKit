import SwiftUI

// The failure this file exists to make impossible:
//
// Sami's settings screen showed "Feedback & Support" and "Enjoying Sami?" as
// rows with a disclosure chevron, and tapping them did nothing at all. Two
// separate causes, both easy to hit:
//
// 1. The host was a custom collapsible card wired to `.constant(false)`, so it
//    could never expand and the `SupportRows` inside it never appeared.
// 2. `SupportSection` / `LoveThisAppSection` are `Section`s. Outside a Form or
//    List a Section renders as nothing — silently, with no warning.
//
// Both leave a row that *looks* interactive and isn't. `SupportDisclosure` owns
// its own presentation: the row is a Button, the content is a sheet it presents
// itself, and neither depends on the host being a Form, a List, a navigation
// stack, or an expander that works. A tap always opens something.

/// Which part of the support surface to show.
public enum SupportSurface: String, Sendable, Hashable, CaseIterable {
    /// Feedback, translation feedback, rating, other apps, and About.
    case everything
    /// Just the ways to write in.
    case feedback
    /// Just the rating ask and the link to the other apps.
    case rating
}

/// How the row opens its content.
public enum SupportDisclosureStyle: Sendable, Hashable {
    /// A sheet the row presents itself. Works in any host — a Form, a List, a
    /// VStack of custom cards, a popover's content view. The default, because
    /// it has no preconditions.
    case sheet
    /// A push onto the enclosing `NavigationStack`. Only choose this when the
    /// row is definitely inside one; a `NavigationLink` outside a navigation
    /// container is inert, which is the bug this type exists to prevent.
    case push
}

/// A self-contained "Feedback & Support" row: title, subtitle, chevron, and a
/// tap that reliably opens the real thing.
///
/// ```swift
/// VStack {
///     SupportDisclosure(app: .sami)                    // everything
///     SupportDisclosure(app: .sami, surface: .rating)  // just the rating ask
/// }
/// ```
public struct SupportDisclosure: View {
    private let app: SuiteApp
    private let surface: SupportSurface
    private let style: SupportDisclosureStyle
    private let extraContext: [String: String]
    private let showsOtherApps: Bool

    @State private var presented = false

    public init(
        app: SuiteApp,
        surface: SupportSurface = .everything,
        style: SupportDisclosureStyle = .sheet,
        extraContext: [String: String] = [:],
        showsOtherApps: Bool = true
    ) {
        self.app = app
        self.surface = surface
        self.style = style
        self.extraContext = extraContext
        self.showsOtherApps = showsOtherApps
    }

    public var body: some View {
        switch style {
        case .sheet:
            Button {
                presented = true
            } label: {
                DisclosureRowLabel(app: app, surface: surface)
            }
            .buttonStyle(.plain)
            // Without this the tap target is the text and icon only; the gap
            // between them and the chevron swallows taps, which reads as "the
            // row doesn't work".
            .contentShape(Rectangle())
            .sheet(isPresented: $presented) {
                SupportSheetContent(
                    app: app, extraContext: extraContext,
                    showsOtherApps: showsOtherApps, surface: surface
                )
            }
        case .push:
            NavigationLink {
                SupportDetailContent(
                    app: app, extraContext: extraContext,
                    showsOtherApps: showsOtherApps, surface: surface
                )
                .navigationTitle(Text(SupportDisclosure.title(app: app, surface: surface)))
            } label: {
                DisclosureRowLabel(app: app, surface: surface, showsChevron: false)
            }
        }
    }

    static func title(app: SuiteApp, surface: SupportSurface) -> String {
        switch surface {
        case .rating:
            return String(localized: "Enjoying \(app.name)?", bundle: .module, comment: "Section header above the rate/more-apps buttons; parameter is the app name")
        case .feedback, .everything:
            return String(localized: "Feedback & Support", bundle: .module, comment: "Section header above the contact-the-developer buttons")
        }
    }
}

/// The row itself, so the sheet and push variants can't drift apart.
struct DisclosureRowLabel: View {
    let app: SuiteApp
    let surface: SupportSurface
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(surface == .rating ? .yellow : .accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(SupportDisclosure.title(app: app, surface: surface))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch surface {
        case .everything: return "lifepreserver"
        case .feedback: return "envelope"
        case .rating: return "star.fill"
        }
    }

    private var subtitle: String {
        switch surface {
        case .everything:
            return String(localized: "Report a bug, suggest a feature, or rate the app", bundle: .module, comment: "Subtitle of the row that opens the support screen")
        case .feedback:
            return String(localized: "Report a bug, suggest a feature, or ask a question", bundle: .module, comment: "Subtitle of the row that opens the feedback screen")
        case .rating:
            return String(localized: "Rate it, or see my other apps", bundle: .module, comment: "Subtitle of the row that opens the rating screen")
        }
    }
}

/// The body of the support surface, without any presentation of its own —
/// a `Form` that can be pushed, embedded, or wrapped in a sheet.
public struct SupportDetailContent: View {
    private let app: SuiteApp
    private let extraContext: [String: String]
    private let showsOtherApps: Bool
    private let surface: SupportSurface

    public init(
        app: SuiteApp,
        extraContext: [String: String] = [:],
        showsOtherApps: Bool = true,
        surface: SupportSurface = .everything
    ) {
        self.app = app
        self.extraContext = extraContext
        self.showsOtherApps = showsOtherApps
        self.surface = surface
    }

    public var body: some View {
        Form {
            if surface != .rating {
                SupportSection(app: app, extraContext: extraContext)
            }
            if surface != .feedback {
                LoveThisAppSection(app: app, showsOtherApps: showsOtherApps)
            }
            if surface == .everything {
                AboutSection(app: app)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

#if DEBUG
struct SupportDisclosure_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SupportDisclosure(app: .sami, surface: .feedback)
            Divider()
            SupportDisclosure(app: .sami, surface: .rating)
        }
        .padding()
    }
}
#endif
