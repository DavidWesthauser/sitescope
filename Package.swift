// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "sitescopeCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "sitescopeCore", targets: ["sitescopeCore"])],
    targets: [
        .target(name: "sitescopeCore", path: "sitescope", exclude: ["AR", "Views", "Resources", "App/sitescopeApp.swift"], sources: ["Core", "Services", "App/Store.swift"]),
        .testTarget(name: "sitescopeCoreTests", dependencies: ["sitescopeCore"], path: "sitescopeTests"),
        .testTarget(name: "sitescopeServiceTests", dependencies: ["sitescopeCore"], path: "sitescopeAppTests")
    ],
    swiftLanguageModes: [.v5]
)
