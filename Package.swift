// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bare-Swift",
    dependencies: [
        .package(url: "https://git.aparoksha.dev/aparoksha/adwaita-swift", branch: "main")
    ],
    targets: [

        .systemLibrary(
            name: "BareC",
            path: "BareLib",
            pkgConfig: nil,
            providers: nil
        ),

        .executableTarget(
            name: "Bare-Swift",
            dependencies: [
                .product(name: "Adwaita", package: "adwaita-swift"),
                .target(name: "BareC"),
            ],
            path: "Sources",
            linkerSettings: [
                .unsafeFlags(["-LBareLib/lib", "-lbare"], .when(platforms: [.linux]))
            ]
        ),
    ]
)
