// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NersCore",
    // `.v26` needs tools-version 6.2; the string form is equivalent and works with 6.0.
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "NersCore", targets: ["NersCore"]),
    ],
    targets: [
        .target(name: "NersCore"),
        .testTarget(name: "NersCoreTests", dependencies: ["NersCore"]),
    ]
)
