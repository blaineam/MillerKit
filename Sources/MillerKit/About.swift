import SwiftUI

// The About block, so no app has to hand-assemble one again. Two things kept
// going wrong when each app rolled its own:
//
// - The version was typed in as a literal and rotted. `AppVersion` reads it
//   from the app bundle, so it can't.
// - The privacy link was composed per app (`/apps/<slug>/privacy/`) and 404'd.
//   There is one policy, at `SuiteApp.defaultPrivacyURL`, and it's the default.

/// Version, privacy policy, and the app's own page — as plain rows, for
/// settings screens built from stacks rather than a `Form`.
public struct AboutRows: View {
    private let app: SuiteApp
    private let showsAppPage: Bool
    @Environment(\.openURL) private var openURL

    public init(app: SuiteApp, showsAppPage: Bool = true) {
        self.app = app
        self.showsAppPage = showsAppPage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle").foregroundColor(.accentColor)
                Text("Version", bundle: .module, comment: "Label for the app's version number in an About screen")
                Spacer()
                Text(AppVersion.display())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            LinkRow(title: String(localized: "Privacy Policy", bundle: .module, comment: "Row that opens the privacy policy in a browser"),
                    icon: "hand.raised.fill", url: app.privacyURL, openURL: openURL)

            if showsAppPage, let page = app.pageURL {
                LinkRow(title: String(localized: "App Website", bundle: .module, comment: "Row that opens the app's own web page"),
                        icon: "globe", url: page, openURL: openURL)
            }

            Text("No accounts, no tracking, no ads — nothing you do in \(app.name) is sent anywhere unless you send it yourself.", bundle: .module, comment: "Footer under the About rows; parameter is the app name")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The same block as a `Section`, for `Form`/`List` screens.
public struct AboutSection: View {
    private let app: SuiteApp
    private let showsAppPage: Bool
    @Environment(\.openURL) private var openURL

    public init(app: SuiteApp, showsAppPage: Bool = true) {
        self.app = app
        self.showsAppPage = showsAppPage
    }

    public var body: some View {
        Section {
            HStack {
                Text("Version", bundle: .module, comment: "Label for the app's version number in an About screen")
                Spacer()
                Text(AppVersion.display())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            LinkRow(title: String(localized: "Privacy Policy", bundle: .module, comment: "Row that opens the privacy policy in a browser"),
                    icon: "hand.raised.fill", url: app.privacyURL, openURL: openURL)

            if showsAppPage, let page = app.pageURL {
                LinkRow(title: String(localized: "App Website", bundle: .module, comment: "Row that opens the app's own web page"),
                        icon: "globe", url: page, openURL: openURL)
            }
        } header: {
            Text("About", bundle: .module, comment: "Section header above the version and privacy rows")
        } footer: {
            Text("No accounts, no tracking, no ads — nothing you do in \(app.name) is sent anywhere unless you send it yourself.", bundle: .module, comment: "Footer under the About rows; parameter is the app name")
        }
    }
}

/// A row that opens a URL. A `Button` calling `openURL` rather than a `Link`
/// on purpose: `Link` inside a custom container picks up the container's
/// styling unpredictably, and this keeps every MillerKit row identical.
struct LinkRow: View {
    let title: String
    let icon: String
    let url: URL
    let openURL: OpenURLAction

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Image(systemName: icon).foregroundColor(.accentColor)
                Text(title).foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundColor(.secondary).font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct About_Previews: PreviewProvider {
    static var previews: some View {
        Form { AboutSection(app: .sami) }
        AboutRows(app: .sami).padding()
    }
}
#endif
