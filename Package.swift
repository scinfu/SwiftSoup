// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftSoup",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "SwiftSoup", targets: ["SwiftSoup"]),
        .executable(name: "SwiftSoupProfile", targets: ["SwiftSoupProfile"])
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/LRUCache.git", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SwiftSoup",
            dependencies: [
                .product(name: "LRUCache", package: "LRUCache"),
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "Sources"),
        .executableTarget(
            name: "SwiftSoupProfile",
            dependencies: ["SwiftSoup"],
            path: "Tools/SwiftSoupProfile"),
        .testTarget(
            name: "SwiftSoupTests", 
            dependencies: [
                "SwiftSoup",
                .product(name: "Atomics", package: "swift-atomics")
            ])
    ]
)
