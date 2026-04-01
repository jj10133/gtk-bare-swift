// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gtk-bare-swift",
    dependencies: [
        .package(url: "https://git.aparoksha.dev/aparoksha/adwaita-swift", from: "0.1.0")
    ],
    targets: [
        // C bridge — exposes bare-kit headers to Swift
        .systemLibrary(
            name: "BareSDK",
            path: "bare-sdk",
            pkgConfig: nil,
            providers: []
        ),

        // Main app
        .executableTarget(
            name: "gtk-bare-swift",
            dependencies: [
                "BareSDK",
                .product(name: "Adwaita", package: "adwaita-swift"),
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags([
                    "-Xcc", "-I./bare-sdk/include",
                    "-Xcc", "-I./bare-sdk/include/linux",
                    "-Xcc", "-I./bare-sdk/include/posix",
                    "-Xcc", "-DBARE_KIT_LINUX",
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L./bare-sdk/lib",
                    "-lbare-kit",
                    "-luv",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "./bare-sdk/lib",
                    "-lpthread", "-ldl", "-lm", "-lstdc++",
                ])
            ]
        ),
    ]
)
