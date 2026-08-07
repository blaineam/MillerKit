import SwiftUI

/// "This app reads badly in my language — let me help fix it."
///
/// Machine translation gets a suite to eighteen languages in an afternoon; it
/// does not get it to *good*. The people who can tell you which line reads like
/// a robot are already using the app in that language, and they are the only
/// ones who can. This is the path that lets them say so.
///
/// Two things make it worth building rather than relying on the generic
/// feedback button:
///
/// 1. **It only appears when it applies.** A user running the app in English
///    has nothing to report, and showing them the row is noise.
/// 2. **It screens first.** A translation fix is a conversation — clarifying
///    what a phrase implies, trying a wording, checking it in context. Somebody
///    who can't comfortably do that in English will have a frustrating time and
///    so will you. Better to say so honestly up front than to start a thread
///    that dies after one message.
public enum TranslationFeedback {

    /// The language the app is actually *displaying* — not the device region,
    /// and not the user's preferred list, but the localization that won.
    /// `Bundle.main.preferredLocalizations.first` is the one that reflects what
    /// they are looking at right now.
    public static func activeLocalization(bundle: Bundle = .main) -> String {
        bundle.preferredLocalizations.first ?? "en"
    }

    /// Whether to offer the flow at all. English speakers reading English copy
    /// have nothing to contribute here.
    public static func isApplicable(bundle: Bundle = .main) -> Bool {
        !activeLocalization(bundle: bundle).lowercased().hasPrefix("en")
    }

    /// Native name of the running localization, for the prompt copy — asking in
    /// terms of "Deutsch" reads far better than "de".
    public static func activeLanguageName(bundle: Bundle = .main) -> String {
        let code = activeLocalization(bundle: bundle)
        return Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized
            ?? Locale.current.localizedString(forIdentifier: code)
            ?? code
    }

    /// Compose the report. Deliberately a `mailto:` like every other MillerKit
    /// path — no server, no account, and the user can see exactly what is being
    /// sent before it goes.
    public static func mailtoURL(
        app: SuiteApp,
        screen: String,
        currentWording: String,
        suggestedWording: String,
        notes: String,
        diagnostics: DiagnosticContext = DiagnosticContext(),
        bundle: Bundle = .main
    ) -> URL? {
        let code = activeLocalization(bundle: bundle)
        let language = activeLanguageName(bundle: bundle)
        let subject = "\(app.name) — Translation fix (\(code))"

        var body = String(
            format: String(localized: """
            Hi Blaine,

            I'd like to help improve the %1$@ translation in %2$@.

            """, bundle: .module, comment: "Opening of a translation-fix email; %1$@ is the language, %2$@ the app name"),
            language, app.name
        )
        body += "\n"
        body += String(localized: "Where in the app:", bundle: .module, comment: "Label in a translation-fix email") + "\n\(screen)\n\n"
        body += String(localized: "What it says now:", bundle: .module, comment: "Label in a translation-fix email") + "\n\(currentWording)\n\n"
        body += String(localized: "What it should say:", bundle: .module, comment: "Label in a translation-fix email") + "\n\(suggestedWording)\n\n"
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body += String(localized: "Why / anything else:", bundle: .module, comment: "Label in a translation-fix email") + "\n\(notes)\n\n"
        }
        body += String(
            localized: "I read and write English comfortably, and I'm happy to go back and forth until the wording is right.",
            bundle: .module,
            comment: "Line confirming the prerequisites, included in the translation-fix email"
        )
        body += "\n\n" + diagnostics.reportFooter
        body += "\n" + String(localized: "Displaying:", bundle: .module, comment: "Label for the app's active language in a report") + " \(language) (\(code))"

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        let s = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "mailto:\(app.supportEmail)?subject=\(s)&body=\(b)")
    }
}

// MARK: - The sheet

/// Gate, then form. The gate is not a hoop for its own sake: it sets the
/// expectation that this is the start of a conversation, which is what makes
/// the difference between a report you can act on and one you can't.
public struct TranslationFeedbackView: View {
    private let app: SuiteApp
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var readsEnglish = false
    @State private var willIterate = false
    @State private var screen = ""
    @State private var currentWording = ""
    @State private var suggestedWording = ""
    @State private var notes = ""

    public init(app: SuiteApp) { self.app = app }

    private var prerequisitesMet: Bool { readsEnglish && willIterate }
    private var canSend: Bool {
        prerequisitesMet
            && !screen.trimmingCharacters(in: .whitespaces).isEmpty
            && !suggestedWording.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var language: String { TranslationFeedback.activeLanguageName() }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This app was translated into \(language) with machine help, and machine help only gets it so far. If something reads wrong, stiff, or just isn't how anyone actually says it — you're the only person who can tell me.", bundle: .module, comment: "Intro explaining why translation feedback is wanted; parameter is the language name")
                        .font(.callout)
                }

                Section {
                    Toggle(isOn: $readsEnglish) {
                        Text("I read and write English comfortably", bundle: .module, comment: "Prerequisite toggle for translation feedback")
                    }
                    Toggle(isOn: $willIterate) {
                        Text("I'm happy to go back and forth on the wording", bundle: .module, comment: "Prerequisite toggle for translation feedback")
                    }
                } header: {
                    Text("Before we start", bundle: .module, comment: "Header above the translation-feedback prerequisites")
                } footer: {
                    // Say plainly why the gate exists, so it doesn't read as
                    // gatekeeping. It's about not wasting the volunteer's time.
                    Text("I only speak English, so getting a translation right means a few messages back and forth. If that isn't something you want to do, please still report it as a normal issue — I'd rather know than not.", bundle: .module, comment: "Footer explaining the prerequisites")
                }

                if prerequisitesMet {
                    Section {
                        TextField(String(localized: "e.g. Settings screen, the Save button", bundle: .module, comment: "Placeholder for where in the app a bad translation appears"), text: $screen, axis: .vertical)
                        TextField(String(localized: "Paste or type what it says now", bundle: .module, comment: "Placeholder for the current wording"), text: $currentWording, axis: .vertical)
                        TextField(String(localized: "What it should say in \(language)", bundle: .module, comment: "Placeholder for the suggested wording; parameter is the language"), text: $suggestedWording, axis: .vertical)
                        TextField(String(localized: "Anything else worth knowing (optional)", bundle: .module, comment: "Placeholder for optional notes"), text: $notes, axis: .vertical)
                    } header: {
                        Text("What needs fixing", bundle: .module, comment: "Header above the translation-feedback fields")
                    }

                    Section {
                        Button {
                            if let url = TranslationFeedback.mailtoURL(
                                app: app, screen: screen, currentWording: currentWording,
                                suggestedWording: suggestedWording, notes: notes
                            ) {
                                openURL(url)
                                dismiss()
                            }
                        } label: {
                            Label {
                                Text("Send it to me", bundle: .module, comment: "Button that sends the translation fix by email")
                            } icon: {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .disabled(!canSend)
                    } footer: {
                        Text("This opens your mail app so you can see exactly what's being sent. Nothing leaves your device until you hit send.", bundle: .module, comment: "Footer clarifying that the report goes out as an ordinary email")
                    }
                }
            }
            .navigationTitle(Text("Improve the \(language) translation", bundle: .module, comment: "Title of the translation feedback screen; parameter is the language"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module, comment: "Dismisses the translation feedback screen")
                    }
                }
            }
        }
    }
}

/// The row that opens the sheet. Renders nothing when the app is running in
/// English, so it can be placed unconditionally at every call site.
public struct TranslationFeedbackButton: View {
    private let app: SuiteApp
    @State private var showing = false

    public init(app: SuiteApp) { self.app = app }

    public var body: some View {
        if TranslationFeedback.isApplicable() {
            Button {
                showing = true
            } label: {
                HStack {
                    Image(systemName: "character.bubble.fill").foregroundColor(.accentColor)
                    Text("Improve the \(TranslationFeedback.activeLanguageName()) translation", bundle: .module, comment: "Button opening the translation feedback screen; parameter is the language")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showing) { TranslationFeedbackView(app: app) }
        }
    }
}
