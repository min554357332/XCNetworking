// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "networking",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "networking",
            targets: ["networking"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.7.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "networking",
            dependencies: [
                "Alamofire",
                .product(name: "Logging", package: "swift-log"),
            ]),
        .testTarget(
            name: "XCNetworkingTests",
            dependencies: ["networking"]),
    ]
)
