// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "test-invest-api-swift-sdk",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/egorbos/invest-api-swift-sdk.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "InvestApiSwiftSdk", package: "invest-api-swift-sdk")
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    ]
)
