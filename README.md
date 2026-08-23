# MillerKit

The small things every app in the suite needs and kept getting re-typed: a
feedback path that produces an actionable bug report, a review prompt that
doesn't lie to itself, and a way to point people at the other apps.

Dependency-free and tiny on purpose — Tilebreak imports this without dragging
in a code editor. iOS 16 / macOS 13 / tvOS 16 / watchOS 9.

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

// 5. Settings / Help / About — inside a Form or List
Form {
    SupportSection(app: app, extraContext: ["Remote": remote.kind])
    LoveThisAppSection(app: app)
    AboutSection(app: app)          // version, privacy policy, app page
}

// …or anywhere at all. SupportDisclosure owns its own presentation, so it
// works in a VStack of custom cards, a popover, a menu — a tap always opens
// something.
VStack {
    SupportDisclosure(app: app, surface: .feedback)
    SupportDisclosure(app: app, surface: .rating)
}
```

### The two URLs you don't get to choose

`supportEmail` defaults to `apps@wemiller.com` and `privacyURL` to
`https://wemiller.com/privacy/`, for every app. Both were per-app once and both
drifted — into mailboxes that were never created and bounce silently, and into
`/apps/<slug>/privacy/` paths that 404. `pageURL` is the one genuinely per-app
URL and stays per-app. `MillerKitTests` asserts this across `SuiteApp.all`.

### Never type a version number

```swift
Text(AppVersion.display())     // "1.3.0 (342)", read from the app bundle
```

`AppVersion` and `DiagnosticContext` read `CFBundleShortVersionString` from
`Bundle.appBundle` — the enclosing `.app`, resolved upward from whatever bundle
they're handed. Code inside a SwiftPM target that reaches for `Bundle.module`
gets the *package's* resource bundle, whose version is its own (usually "1.0")
and never the app's; nothing crashes, the About row just reports the wrong
number forever. That is how Sami shipped 1.3.0 showing "Version 1.0.0".

## What each piece does

| Type | Role |
|---|---|
| `SuiteApp` | Name, App Store ID, per-app page URL — plus the suite-wide support address and privacy policy. `SuiteRegistry.swift` has one per shipping app, and `SuiteApp.all` lists them. |
| `AppVersion` / `Bundle.appBundle` | The app's version and build, read from the app bundle and nowhere else. |
| `DiagnosticContext` | App version + build, OS version, `iPhone17,1`-style hardware id, locale. Rendered as a labelled, explained block — not an opaque payload people delete. |
| `Feedback.mailtoURL` | Guided `mailto:` per kind (bug / feature / question), plus optional per-app `extraContext`. Escapes `&=+?#`, which is what stops a body containing `&` from truncating the email. |
| `RatingManager` | Decides *whether* to ask. Does not ask. |
| `SupportSection` | Three buttons + the "I can't fix what I don't know about" footer. |
| `LoveThisAppSection` | Rate + My Other Apps, with the honest reason a rating matters. Apps with a `supportURL` (the free, donation-funded ones: Haven, Blip, Glint) also get a **Support Future Development** row that opens https://wemiller.com/support/ — the one page listing every way to fund the work (GitHub Sponsors, Ko-fi, a one-time tip), so adding or dropping a service is a website edit, not an app release. |
| `AboutSection` / `AboutRows` | Version, privacy policy, app page — as a `Section` or as plain rows. |
| `SupportDisclosure` | A self-contained row: title, subtitle, chevron, and a tap that presents the real content. No Form, List, or navigation stack required. |
| `SupportSheetButton` / `SupportWindowContent` | Presentation shells for apps with no settings screen (iOS sheet, macOS window). |

## The support row is opt-in, and only for the free apps

`SuiteApp.supportURL` is `nil` by default. The registry sets it (to
`SuiteApp.defaultSupportURL`) for exactly three apps — Haven, Blip and Glint — because
those are free, with no ads and no purchases, and are funded by the people who want them to
exist. A paid app asking for donations reads as odd, and every external funding link inside
an App Store build is something App Review can read as a purchase mechanism (Guideline
3.1.1), so the blast radius is kept to the apps that actually need it. The test
`testOnlyTheFreeAppsCarryTheSupportRow` pins that list; widening it is a deliberate edit to
the registry and the test, not a default.

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

## Rows that look tappable must be tappable

`SupportSection` and `LoveThisAppSection` are `Section`s: outside a `Form` or
`List` they render as *nothing*, silently. Sami paired that with a collapsible
card wired to `.constant(false)`, and shipped two rows with disclosure chevrons
that did nothing when tapped.

`SupportDisclosure` is the answer for any host that isn't a Form: the row is a
`Button`, the content is a sheet it presents itself, and `contentShape` makes
the whole row — not just the text — the tap target. `style: .push` is available
for rows that are definitely inside a `NavigationStack`; the default `.sheet`
has no preconditions at all.

## Tests

`swift test` — 27 tests covering mailto escaping, context ordering, review-URL
construction, the suite-wide support address and privacy URL across every
registered app, version resolution out of a package bundle, the questions each
feedback template must keep asking, and every rating gate including the cooldown
regression.

> On an iCloud-synced checkout, `swift test` can fail codesigning with
> "resource fork, Finder information, or similar detritus not allowed".
> Build elsewhere: `swift test --scratch-path /tmp/millerkit-build`.
