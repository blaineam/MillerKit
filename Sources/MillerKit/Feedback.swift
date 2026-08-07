import Foundation

/// What the person is writing in about. Each kind gets its own guided template,
/// because "email me if you have a problem" reliably produces "it doesn't work"
/// and a guided form reliably produces something reproducible.
public enum FeedbackKind: String, CaseIterable, Sendable {
    case bug
    case feature
    case question

    public var subjectSuffix: String {
        switch self {
        case .bug: return String(localized: "Bug Report", bundle: .module, comment: "Email subject suffix")
        case .feature: return String(localized: "Feature Request", bundle: .module, comment: "Email subject suffix")
        case .question: return String(localized: "Question", bundle: .module, comment: "Email subject suffix")
        }
    }
}

public enum Feedback {
    /// A `mailto:` URL pre-filled with a guided template plus the diagnostic
    /// block, so a report arrives actionable instead of needing three rounds of
    /// "which version are you on?".
    ///
    /// - Parameter extraContext: app-specific state worth attaching (the remote
    ///   type, the current board, the export format). Appended above the
    ///   diagnostics, one `key: value` per line.
    public static func mailtoURL(
        app: SuiteApp,
        kind: FeedbackKind,
        diagnostics: DiagnosticContext = DiagnosticContext(),
        extraContext: [String: String] = [:]
    ) -> URL? {
        let subject = "\(app.name) — \(kind.subjectSuffix)"
        var body = template(for: kind, appName: app.name)

        if !extraContext.isEmpty {
            body += "\n\n"
            body += extraContext.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }
        body += "\n\n" + diagnostics.reportFooter

        // mailto query encoding: start from urlQueryAllowed, then remove the
        // sub-delimiters that would terminate or corrupt the query string.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        let s = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let b = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "mailto:\(app.supportEmail)?subject=\(s)&body=\(b)")
    }

    static func template(for kind: FeedbackKind, appName: String) -> String {
        switch kind {
        case .bug:
            return String(
                format: String(localized: """
                Hi Blaine,

                I ran into a problem with %@.

                What went wrong:


                Steps to reproduce:
                1.
                2.
                3.

                What I expected to happen:


                How often it happens (always / sometimes / once):

                """, bundle: .module, comment: "Body template for a bug report email; %@ is the app name"),
                appName
            )
        case .feature:
            return String(
                format: String(localized: """
                Hi Blaine,

                I have an idea for %@.

                What I'd like to be able to do:


                Why it would help / the problem it solves:


                How I imagine it working:

                """, bundle: .module, comment: "Body template for a feature request email; %@ is the app name"),
                appName
            )
        case .question:
            return String(
                format: String(localized: """
                Hi Blaine,

                I have a question about %@.

                What I'm trying to do:


                What I've tried so far:

                """, bundle: .module, comment: "Body template for a support question email; %@ is the app name"),
                appName
            )
        }
    }
}
