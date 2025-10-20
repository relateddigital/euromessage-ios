// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Euromsg",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        // 'type: .dynamic' kaldırıldı. Bu, SPM'in hedefe göre en uygun linkleme türünü
        // (extension'lar için statik) seçmesine olanak tanır.
        .library(
            name: "Euromsg",
            targets: ["Euromsg"]
        )
    ],
    dependencies: [
        // Projenizin başka bağımlılıkları varsa buraya ekleyebilirsiniz.
    ],
    targets: [
        .target(
            name: "Euromsg",
            dependencies: [],
            path: "Sources/Euromsg/Classes",
            // Karusel özelliğinin çalışması için gerekli olan .xib dosyalarını
            // kaynak olarak ekliyoruz.
            resources: [
                .process("EMNotificationCarousel/EMNotificationCarousel.xib"),
                .process("EMNotificationCarousel/CarouselCell.xib")
            ]
        ),
        .testTarget(
            name: "EuromsgTests",
            dependencies: ["Euromsg"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
