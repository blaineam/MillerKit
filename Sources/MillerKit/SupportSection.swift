import SwiftUI

/// Drop-in `Section` for any Settings/Help/About screen. One import, one line,
/// identical wording in every app — which is the point: this exact block was
/// being re-typed per app and drifting.
///
/// ```swift
/// Form {
///     …
///     SupportSection(app: .enterSpace)
///     LoveThisAppSection(app: .enterSpace)
/// }
/// ```
public struct SupportSection: View {
    private let app: SuiteApp
    private let extraContext: [String: String]
    @Environment(\.openURL) private var openURL

    /// - Parameter extraContext: app state worth attaching to every report —
    ///   the active remote type, the current level, the chosen export format.
    public init(app: SuiteApp, extraContext: [String: String] = [:]) {
        self.app = app
        self.extraContext = extraContext
    }

    public var body: some View {
        Section {
            row(.bug, title: String(localized: "Report an Issue", bundle: .module, comment: "Button that opens an email to report a bug"), icon: "ladybug.fill")
            row(.feature, title: String(localized: "Suggest a Feature", bundle: .module, comment: "Button that opens an email to request a feature"), icon: "lightbulb.fill")
            row(.question, title: String(localized: "Ask a Question", bundle: .module, comment: "Button that opens an email to ask a support question"), icon: "questionmark.circle.fill")
            // Renders nothing when the app is running in English, so it can sit
            // here unconditionally in every app.
            TranslationFeedbackButton(app: app)
        } header: {
            Text("Feedback & Support", bundle: .module, comment: "Section header above the contact-the-developer buttons")
        } footer: {
            // The ask, stated plainly. People assume a solo developer already
            // knows the app is broken; saying otherwise is what turns a silent
            // uninstall into a fixable report.
            Text("I can't fix what I don't know about. If something is broken, confusing, or missing, email me — one person reads every message, and a fix for you is a fix for everyone.", bundle: .module, comment: "Footer under the feedback buttons, explaining why to write in")
        }
    }

    private func row(_ kind: FeedbackKind, title: String, icon: String) -> some View {
        Button {
            if let url = Feedback.mailtoURL(app: app, kind: kind, extraContext: extraContext) {
                openURL(url)
            }
        } label: {
            HStack {
                Image(systemName: icon).foregroundColor(.accentColor)
                Text(title).foregroundColor(.primary)
                Spacer()
                Image(systemName: "envelope").foregroundColor(.secondary).font(.caption)
            }
        }
    }
}

/// The "if you like it, say so" block. Separate from `SupportSection` on
/// purpose: a rating ask sitting next to a bug-report button reads as asking
/// for a favour from someone who came to complain.
public struct LoveThisAppSection: View {
    private let app: SuiteApp
    private let showsOtherApps: Bool
    @Environment(\.openURL) private var openURL

    public init(app: SuiteApp, showsOtherApps: Bool = true) {
        self.app = app
        self.showsOtherApps = showsOtherApps
    }

    public var body: some View {
        Section {
            if let review = app.writeReviewURL {
                Button {
                    openURL(review)
                } label: {
                    HStack {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate \(app.name)", bundle: .module, comment: "Button title; parameter is the app name")
                                .foregroundColor(.primary)
                            Text("Ratings are how people find it", bundle: .module, comment: "Subtitle under the rate button")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundColor(.secondary).font(.caption)
                    }
                }
            }
            if showsOtherApps {
                Button {
                    openURL(app.portfolioURL)
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Other Apps", bundle: .module, comment: "Button that opens the developer's app portfolio")
                                .foregroundColor(.primary)
                            Text("Built by one person, same care", bundle: .module, comment: "Subtitle under the other-apps button")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        } header: {
            Text("Enjoying \(app.name)?", bundle: .module, comment: "Section header above the rate/more-apps buttons; parameter is the app name")
        } footer: {
            Text("\(app.name) is made by one person, with no ads, no tracking, and no venture money behind it. A rating takes ten seconds and genuinely decides whether anyone else ever sees it.", bundle: .module, comment: "Footer explaining why a rating matters")
        }
    }
}

#if DEBUG
struct SupportSection_Previews: PreviewProvider {
    static let demo = SuiteApp(
        name: "Enter Space",
        supportEmail: "enter-space@wemiller.com",
        appStoreID: "6746350540",
        pageURL: URL(string: "https://wemiller.com/apps/enter-space/")
    )
    static var previews: some View {
        Form {
            SupportSection(app: demo)
            LoveThisAppSection(app: demo)
        }
    }
}
#endif
