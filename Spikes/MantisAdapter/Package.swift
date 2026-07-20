// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TailorMantisAdapter",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TailorMantisAdapter", targets: ["TailorMantisAdapter"])
    ],
    dependencies: [
        .package(url: "https://github.com/guoyingtao/Mantis.git", exact: "3.1.0")
    ],
    targets: [
        .target(
            name: "TailorMantisAdapter",
            dependencies: [.product(name: "Mantis", package: "Mantis")]
        ),
        .testTarget(
            name: "TailorMantisAdapterTests",
            dependencies: ["TailorMantisAdapter", .product(name: "Mantis", package: "Mantis")]
        )
    ]
)
