// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SwiftSoup",
    products: [
        .library(name: "SwiftSoup", targets: ["SwiftSoup"])
    ],
    targets: [
        .target(name: "SwiftSoup", path: "Sources"),
        .testTarget(name: "SwiftSoupTests", dependencies: ["SwiftSoup"])
    ]
)
