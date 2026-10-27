// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NersCore",
    // `.v26` cần tools-version 6.2, dạng chuỗi tương đương và chạy được với 6.0.
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "NersCore", targets: ["NersCore"]),
    ],
    targets: [
        .target(name: "NersCore"),
        .testTarget(name: "NersCoreTests", dependencies: ["NersCore"]),
    ]
)
