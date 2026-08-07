# MillerKit

The small things every app in the suite needs and kept getting re-typed: a
feedback path that produces an actionable bug report, a review prompt that
doesn't lie to itself, and a way to point people at the other apps.

Dependency-free and tiny on purpose — Tilebreak imports this without dragging
in a code editor. iOS 17 / macOS 14 / tvOS 17 / watchOS 10.

This is the `MillerKit.AppStoreRating` module
[`_shared/docs/SUITE-FINDINGS-AND-BACKLOG.md` §4.6](../../_shared/docs/SUITE-FINDINGS-AND-BACKLOG.md)
has been asking for, with the three correctness bugs from §4.4 actually fixed.

## Wiring an app

```swift
import MillerKit

// 1. Identity — already declared for every shipping app in SuiteRegistry.swift
let app = SuiteApp.enterSpace

// 2. Rating gates, once, at the App level
@StateObject private var rating = RatingManager(gates: .utility)   // or .game

var body: some Scene {
    WindowGroup {
        ContentView()
            .environmentObject(rating)
            .task { rating.recordLaunch() }        // once per cold launch
    }
}

// 3. Count outcomes the app EXISTS to produce — completed, never attempted
rating.recordSignificantAction()     // sync finished, board cleared, export written

// 4. Ask on a success view, never on an error path
.requestReviewAfterSuccess(rating, when: syncDidFinish)

// 5. Settings / Help / About
Form {
    SupportSection(app: app, extraContext: ["Remote": remote.kind])
    LoveThisAppSection(app: app)
}
```

## What each piece does

| Type | Role |
|---|---|
| `SuiteApp` | Name, support address, App Store ID, portfolio URL. `SuiteRegistry.swift` has one per shipping app. |
| `DiagnosticContext` | App version + build, OS version, `iPhone17,1`-style hardware id, locale. Rendered as a labelled, explained block — not an opaque payload people delete. |
| `Feedback.mailtoURL` | Guided `mailto:` per kind (bug / feature / question), plus optional per-app `extraContext`. Escapes `&=+?#`, which is what stops a body containing `&` from truncating the email. |
| `RatingManager` | Decides *whether* to ask. Does not ask. |
| `SupportSection` | Three buttons + the "I can't fix what I don't know about" footer. |
| `LoveThisAppSection` | Rate + My Other Apps, with the honest reason a rating matters. |

## Why `RatingManager` doesn't call StoreKit itself

The view owns `@Environment(\.requestReview)`, so the system resolves the host
window. That is the fix for the documented macOS failure where a menu-bar app
had no key window, the old code resolved no host, and the prompt silently never
appeared — for the entire life of the install, because the same code had already
set its one-shot flag.

The other two fixes:

- **Cooldown, not one-shot.** StoreKit shows the sheet at most ~3×/year and may
  show nothing. `recordAttempt()` starts a 120-day cooldown; it never claims the
  sheet appeared, because StoreKit doesn't tell us.
- **Never twice on one version.** If they didn't rate after the last ask, asking
  again on the same build is nagging.

Gates are `launches ≥ 10 && days ≥ 7 && significantActions ≥ 3` for utilities,
`5 / 2 / 5` for games — a game earns a "job done" moment far faster than a file
manager does.

`rating.debugSummary` prints the whole gate state for a debug row;
`resetForTesting()` clears it.

## Localization

Every user-visible string goes through `String(localized:bundle: .module)`
against `Resources/Localizable.xcstrings`, so the strings localize with the rest
of the suite and fall back to English automatically. `Bundle.module` only exists
because that catalog is declared as a resource — remove it and every string
silently becomes a compile error.

## Tests

`swift test` — 9 tests covering mailto escaping, context ordering, review-URL
construction, and every rating gate including the cooldown regression.
