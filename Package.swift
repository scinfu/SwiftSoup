// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftSoup",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "SwiftSoup", targets: ["SwiftSoup"]),
        .executable(name: "SwiftSoupProfile", targets: ["SwiftSoupProfile"])
    ],
    targets: [
        .target(
            name: "SwiftSoup",
            path: "Sources"),
        .executableTarget(
            name: "SwiftSoupProfile",
            dependencies: ["SwiftSoup"],
            path: "Tools/SwiftSoupProfile"),
        .testTarget(
            name: "SwiftSoupTests",
            dependencies: ["SwiftSoup"])
    ]
)
