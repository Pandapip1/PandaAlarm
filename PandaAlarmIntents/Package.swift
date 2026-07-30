// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PandaAlarmIntents",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PandaAlarmIntents", targets: ["PandaAlarmIntents"]),
    ],
    targets: [
        .target(name: "PandaAlarmIntents"),
    ]
)
