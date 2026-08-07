import SwiftUI

// `SupportSection` / `LoveThisAppSection` are `Section`s, so they only render
// inside a Form or List. Several apps lay their settings out as a VStack of
// custom cards (Sami's CollapsibleSection, for one), where a Section silently
// collapses to nothing. These are the same rows without the container.

/// One feedback button. Compose freely, or use `SupportRows` for all three.
public struct FeedbackButton: View {
    private let app: SuiteApp
    private let kind: FeedbackKind
    private let extraContext: [String: String]
    @Environment(\.openURL) private var openURL

    public init(app: SuiteApp, kind: FeedbackKind, extraContext: [String: String] = [:]) {
        self.app = app
        self.kind = kind
        self.extraContext = extraContext
    }

    public var body: some View {
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
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch kind {
        case .bug: return "ladybug.fill"
        case .feature: return "lightbulb.fill"
        case .question: return "questionmark.circle.fill"
        }
    }

    private var title: String {
        switch kind {
        case .bug: return String(localized: "Report an Issue", bundle: .module, comment: "Button that opens an email to report a bug")
        case .feature: return String(localized: "Suggest a Feature", bundle: .module, comment: "Button that opens an email to request a feature")
        case .question: return String(localized: "Ask a Question", bundle: .module, comment: "Button that opens an email to ask a support question")
        }
    }
}

/// The three feedback buttons plus the "email me" explanation, as a plain
/// `VStack` — for settings screens that aren't built from a Form.
public struct SupportRows: View {
    private let app: SuiteApp
    private let extraContext: [String: String]

    public init(app: SuiteApp, extraContext: [String: String] = [:]) {
        self.app = app
        self.extraContext = extraContext
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(FeedbackKind.allCases, id: \.self) { kind in
                FeedbackButton(app: app, kind: kind, extraContext: extraContext)
            }
            TranslationFeedbackButton(app: app)
            Text("I can't fix what I don't know about. If something is broken, confusing, or missing, email me — one person reads every message, and a fix for you is a fix for everyone.", bundle: .module, comment: "Footer under the feedback buttons, explaining why to write in")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Rate + other apps, as a plain `VStack`.
public struct LoveThisAppRows: View {
    private let app: SuiteApp
    private let showsOtherApps: Bool
    @Environment(\.openURL) private var openURL

    public init(app: SuiteApp, showsOtherApps: Bool = true) {
        self.app = app
        self.showsOtherApps = showsOtherApps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let review = app.writeReviewURL {
                Button { openURL(review) } label: {
                    HStack {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        Text("Rate \(app.name)", bundle: .module, comment: "Button title; parameter is the app name")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundColor(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            if showsOtherApps {
                Button { openURL(app.portfolioURL) } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill").foregroundColor(.accentColor)
                        Text("My Other Apps", bundle: .module, comment: "Button that opens the developer's app portfolio")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundColor(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            Text("\(app.name) is made by one person, with no ads, no tracking, and no venture money behind it. A rating takes ten seconds and genuinely decides whether anyone else ever sees it.", bundle: .module, comment: "Footer explaining why a rating matters")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
