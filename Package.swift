// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CatchLama",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    ],
    targets: [
        .executableTarget(name: "CatchLama", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .testTarget(name: "CatchLamaTests", dependencies: ["CatchLama"]),
    ]
)
