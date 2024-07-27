// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftSoup",
    platforms: [.macOS(.v11), .iOS(.v13), .watchOS(.v4)],
    products: [
        .library(name: "SwiftSoup", targets: ["SwiftSoup"])
    ],
    targets: [
        .target(name: "SwiftSoup",
                path: "Sources",
                exclude: [],
                resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "SwiftSoupTests", dependencies: ["SwiftSoup"])
    ]
)


