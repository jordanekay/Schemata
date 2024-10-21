// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "Schemata",
    products: [
        .library(
            name: "Schemata",
            targets: ["Schemata"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Schemata",
            dependencies: [
            ],
            path: "Sources"
        )
    ]
)
