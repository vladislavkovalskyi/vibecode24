// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Vibecode24",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vibecode24", targets: ["Vibecode24"]),
    ],
    targets: [
        .target(
            name: "VibeCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Vibecode24",
            dependencies: ["VibeCore"],
            linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("ServiceManagement")]
        ),
        .testTarget(name: "VibeCoreTests", dependencies: ["VibeCore"]),
    ],
    swiftLanguageModes: [.v5]
)
