// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftSoup",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "SwiftSoup", targets: ["SwiftSoup"])
    ],
    targets: [
        .target(
            name: "SwiftSoup",
            path: "Sources"),
        .testTarget(
            name: "SwiftSoupTests", 
            dependencies: ["SwiftSoup"])
    ]
)
