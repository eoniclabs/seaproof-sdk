// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "seaproof",
    platforms: [.iOS(.v13)],
    products: [.library(name: "seaproof", targets: ["seaproof"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [.target(name: "seaproof", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")])]
)
