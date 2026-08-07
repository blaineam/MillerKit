// swift-tools-version: 5.9
import PackageDescription

// MillerKit — the small things every app in the suite needs and kept
// copy-pasting: a feedback path that produces actionable email, a review
// prompt that doesn't lie to itself about whether Apple showed the sheet, and
// a way to point people at the rest of the apps.
//
// Deliberately dependency-free and tiny: Tilebreak has to be able to import
// this without dragging in a code editor.
let package = Package(
    name: "MillerKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "MillerKit", targets: ["MillerKit"]),
    ],
    targets: [
        // The String Catalog is what makes `Bundle.module` exist, which is what
        // every `String(localized:bundle: .module)` in here resolves against.
        // Without a resource, SwiftPM doesn't synthesize the bundle at all.
        .target(name: "MillerKit", resources: [.process("Resources")]),
        .testTarget(name: "MillerKitTests", dependencies: ["MillerKit"]),
    ]
)
