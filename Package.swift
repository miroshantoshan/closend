// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Closend",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Closend",
            path: "Sources/Closend",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
