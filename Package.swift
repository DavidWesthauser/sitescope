// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SiteARCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "SiteARCore", targets: ["SiteARCore"])],
    targets: [
        .target(
            name: "SiteARCore", path: "SiteAR", exclude: ["AR", "Views", "Resources", "App/SiteARApp.swift"],
            sources: ["Core", "Services", "App/Store.swift"]),
        .testTarget(name: "SiteARCoreTests", dependencies: ["SiteARCore"], path: "SiteARTests"),
        .testTarget(name: "SiteARServiceTests", dependencies: ["SiteARCore"], path: "SiteARAppTests"),
    ],
    swiftLanguageModes: [.v5]
)
