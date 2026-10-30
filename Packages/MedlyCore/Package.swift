// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MedlyCore",
    // `.v26` needs tools-version 6.2; the string form is equivalent and works with 6.0.
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "MedlyCore", targets: ["MedlyCore"]),
    ],
    targets: [
        .target(name: "MedlyCore"),
        .testTarget(name: "MedlyCoreTests", dependencies: ["MedlyCore"]),
    ]
)
