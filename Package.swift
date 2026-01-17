// swift-tools-version:6.0

import Foundation
import PackageDescription

let swiftSoupSwiftSettings: [SwiftSetting] = []

let swiftSoupLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("xml2", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
    .linkedLibrary("xml2", .when(platforms: [.linux]))
]

var swiftSoupDependencies: [Target.Dependency] = [
    .product(name: "LRUCache", package: "LRUCache"),
    .product(name: "Atomics", package: "swift-atomics"),
    .target(name: "SwiftSoupCLibxml2Scan"),
    .target(name: "CLibxml2", condition: .when(platforms: [.linux]))
]

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
        .systemLibrary(
            name: "CLibxml2",
            pkgConfig: "libxml-2.0",
            providers: [
                .brew(["libxml2"]),
                .apt(["libxml2-dev"])
            ]
        ),
        .target(
            name: "SwiftSoup",
            dependencies: swiftSoupDependencies,
            path: "Sources",
            exclude: ["SwiftSoupCLibxml2Scan"],
            swiftSettings: swiftSoupSwiftSettings,
            linkerSettings: swiftSoupLinkerSettings),
        .target(
            name: "SwiftSoupCLibxml2Scan",
            path: "Sources/SwiftSoupCLibxml2Scan",
            publicHeadersPath: "include"),
        .executableTarget(
            name: "SwiftSoupProfile",
            dependencies: ["SwiftSoup"],
            path: "Tools/SwiftSoupProfile",
            swiftSettings: swiftSoupSwiftSettings),
        .testTarget(
            name: "SwiftSoupTests",
            dependencies: [
                "SwiftSoup",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "Tests/SwiftSoupTests"
        ),
        .testTarget(
            name: "SwiftSoupTestsLibxml2",
            dependencies: [
                "SwiftSoup",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "Tests/SwiftSoupTestsLibxml2",
            swiftSettings: [
                .define("SWIFTSOUP_TEST_BACKEND_LIBXML2")
            ]
        ),
        .testTarget(
            name: "SwiftSoupTestsLibxml2Only",
            dependencies: [
                "SwiftSoup",
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "Tests/SwiftSoupTestsLibxml2Only",
            swiftSettings: [
                .define("SWIFTSOUP_TEST_BACKEND_LIBXML2"),
                .define("SWIFTSOUP_TEST_LIBXML2_ONLY")
            ]
        )
    ]
)
