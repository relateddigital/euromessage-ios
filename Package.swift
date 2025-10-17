// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Euromsg",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "Euromsg",
            type: .dynamic, // önemli olabilir
            targets: ["Euromsg"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Euromsg",
            dependencies: [],
            path: "Sources/Euromsg/Classes" // burada sınıflar olduğu için
        ),
        .testTarget(
            name: "EuromsgTests",
            dependencies: ["Euromsg"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
