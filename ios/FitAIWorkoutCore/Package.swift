// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitAIWorkoutCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "FitAIWorkoutCore", targets: ["FitAIWorkoutCore"])
    ],
    targets: [
        .target(
            name: "FitAIWorkoutCore",
            path: "Sources/FitAIWorkoutCore"
        ),
        .testTarget(
            name: "FitAIWorkoutCoreTests",
            dependencies: ["FitAIWorkoutCore"],
            path: "Tests/FitAIWorkoutCoreTests"
        )
    ]
)
