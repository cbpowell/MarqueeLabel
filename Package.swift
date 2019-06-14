// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MarqueeLabel",
    products: [
        .library(name: "MarqueeLabel", targets: ["MarqueeLabel"]),
    ],
    targets: [
        .target(
            name: "MarqueeLabel",
            path: "Sources"),
    ]
)
