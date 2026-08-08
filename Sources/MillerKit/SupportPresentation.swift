import SwiftUI

// The sections and rows in this package assume the app already has somewhere
// to put them — a Settings form, an About screen. Plenty of apps don't: an
// iOS game with no settings at all, or a macOS menu-bar app whose only UI is
// a popover. These are the two presentation shells for those cases.
//
// The split is deliberate and platform-shaped:
//
// - **iOS: a sheet.** `SupportSheetButton` is a self-contained button that
//   presents the support content modally. On iOS a sheet is a first-class,
//   full-height surface and the natural home for "everything else".
// - **macOS menu-bar apps: a real window, never a sheet.** A sheet attaches
//   to the window it was presented from — and a menu-bar popover is a
//   transient, self-dismissing window. The sheet dies with the popover, or
//   pins the popover open under it; either way it's broken. Host
//   `SupportWindowContent` in a dedicated `Window` scene (or an app-managed
//   `NSWindow`) instead:
//
//   ```swift
//   Window("Support MyApp", id: "support") {
//       SupportWindowContent(app: .myApp)
//   }
//   ```

/// A button that presents the full support surface — the three feedback rows,
/// translation feedback, and the rate/other-apps block — as a sheet. For apps
/// with no settings screen to embed `SupportSection` in.
public struct SupportSheetButton<Label: View>: View {
    private let app: SuiteApp
    private let extraContext: [String: String]
    private let showsOtherApps: Bool
    private let label: Label
    @State private var showing = false

    /// - Parameters:
    ///   - extraContext: app state worth attaching to every report.
    ///   - label: the button's own appearance, styled by the caller to fit the
    ///     screen it sits on.
    public init(
        app: SuiteApp,
        extraContext: [String: String] = [:],
        showsOtherApps: Bool = true,
        @ViewBuilder label: () -> Label
    ) {
        self.app = app
        self.extraContext = extraContext
        self.showsOtherApps = showsOtherApps
        self.label = label()
    }

    public var body: some View {
        Button {
            showing = true
        } label: {
            label
        }
        .sheet(isPresented: $showing) {
            SupportSheetContent(app: app, extraContext: extraContext, showsOtherApps: showsOtherApps)
        }
    }
}

public extension SupportSheetButton where Label == SwiftUI.Label<Text, Image> {
    /// The default look: a lifepreserver and "Support & Feedback".
    init(app: SuiteApp, extraContext: [String: String] = [:], showsOtherApps: Bool = true) {
        self.init(app: app, extraContext: extraContext, showsOtherApps: showsOtherApps) {
            SwiftUI.Label {
                Text("Support & Feedback", bundle: .module, comment: "Button that opens the support sheet")
            } icon: {
                Image(systemName: "lifepreserver")
            }
        }
    }
}

/// What the sheet shows. Public so an app that wants its own presentation —
/// a popover on iPad, a push on a navigation stack — can reuse the content
/// without the button.
public struct SupportSheetContent: View {
    private let app: SuiteApp
    private let extraContext: [String: String]
    private let showsOtherApps: Bool
    @Environment(\.dismiss) private var dismiss

    public init(app: SuiteApp, extraContext: [String: String] = [:], showsOtherApps: Bool = true) {
        self.app = app
        self.extraContext = extraContext
        self.showsOtherApps = showsOtherApps
    }

    public var body: some View {
        NavigationStack {
            Form {
                SupportSection(app: app, extraContext: extraContext)
                LoveThisAppSection(app: app, showsOtherApps: showsOtherApps)
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(Text("Support & Feedback", bundle: .module, comment: "Title of the support sheet"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", bundle: .module, comment: "Dismisses the support sheet")
                    }
                }
            }
        }
    }
}

#if os(macOS)
/// The support surface for a macOS app that has no Form-based settings to
/// embed the sections in — menu-bar apps above all. Host it in a dedicated
/// `Window` scene (or an app-managed `NSWindow`); it is a complete window
/// body, sized for the content. Never present this as a sheet from a menu-bar
/// popover — the popover is transient and takes the sheet down with it.
public struct SupportWindowContent: View {
    private let app: SuiteApp
    private let extraContext: [String: String]
    private let showsOtherApps: Bool

    public init(app: SuiteApp, extraContext: [String: String] = [:], showsOtherApps: Bool = true) {
        self.app = app
        self.extraContext = extraContext
        self.showsOtherApps = showsOtherApps
    }

    public var body: some View {
        Form {
            SupportSection(app: app, extraContext: extraContext)
            LoveThisAppSection(app: app, showsOtherApps: showsOtherApps)
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 440, maxWidth: 560,
               minHeight: 420, idealHeight: 560, maxHeight: .infinity)
    }
}
#endif

#if DEBUG
struct SupportPresentation_Previews: PreviewProvider {
    static var previews: some View {
        SupportSheetContent(app: .blip)
        #if os(macOS)
        SupportWindowContent(app: .glint)
        #endif
    }
}
#endif
