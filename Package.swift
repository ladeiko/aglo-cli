// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "aglo-cli",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "aglo-cli", targets: ["aglo-cli"]),
        .executable(name: "aglo-sync", targets: ["aglo-sync"]),
        .library(name: "CLICommands", targets: ["CLICommands"]),
        .library(name: "StringsFileParser", targets: ["StringsFileParser"]),
        .library(name: "CommentParser", targets: ["CommentParser"]),
        .library(name: "TokenParser", targets: ["TokenParser"]),
        .library(name: "Utils", targets: ["Utils"]),
        .library(name: "Rollback", targets: ["Rollback"]),
        .library(name: "XMLTokenParser", targets: ["XMLTokenParser"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jakeheis/SwiftCLI", from: "6.0.3"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.6.0")
    ],
    targets: [

        // Main
        .target(
            name: "aglo-cli",
            dependencies: [
                "CLICommands",
                "SwiftCLI",
            ]),

        .target(
            name: "aglo-sync",
            dependencies: [
                "Sync",
            ]),

        // Libs
        .target(
            name: "Sync",
            dependencies: [
                "StringsFileParser",
                "PathKit",
                "Rollback",
                "Utils",
            ]),
        .target(
            name: "CLICommands",
            dependencies: [
                "StringsFileParser",
                "PathKit",
                "SwiftCLI",
                "SwiftCSV",
                "Rollback",
                "Sync",
            ]),
        .target(
            name: "StringsFileParser",
            dependencies: [
                "PathKit",
                "CommentParser",
                "TokenParser",
            ]),
        .target(
            name: "CommentParser",
            dependencies: [
                "TokenParser",
            ]),
        .target(
            name: "TokenParser",
            dependencies: [
                "Utils",
            ]),
        .target(
            name: "XMLTokenParser",
            dependencies: [
                "Utils",
            ]),
        .target(
            name: "Rollback",
            dependencies: [
                "PathKit",
            ]),
        .target(
            name: "Utils",
            dependencies: [
                "PathKit",
            ]),

        // Tests
        .testTarget(
            name: "CLICommandsTests",
            dependencies: [
                "CLICommands",
                "SwiftCLI",
                "StringsFileParser",
            ]),
        .testTarget(
            name: "StringsFileParserTests",
            dependencies: [
                "StringsFileParser",
            ]),
        .testTarget(
            name: "TokenParserTests",
            dependencies: [
                "TokenParser",
            ]),
        .testTarget(
            name: "CommentParserTests",
            dependencies: [
                "CommentParser",
            ]),
        .testTarget(
            name: "UtilsTests",
            dependencies: [
                "Utils",
            ]),
        .testTarget(
            name: "RollbackTests",
            dependencies: [
                "Rollback",
            ]),
        .testTarget(
            name: "XMLTokenParserTests",
            dependencies: [
                "XMLTokenParser",
            ]),
    ]
)
