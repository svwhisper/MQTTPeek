// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MQTTPeek",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.2.6")
    ],
    targets: [
        .executableTarget(
            name: "MQTTPeek",
            dependencies: ["CocoaMQTT"]
        )
    ]
)
