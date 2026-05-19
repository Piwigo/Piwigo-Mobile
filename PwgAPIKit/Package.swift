// swift-tools-version: 5.9
//
//  Package.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 17/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PwgAPIKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgAPIKit",
            targets: ["PwgAPIKit"]
        )
    ],
    dependencies: [
        .package(path: "../PwgKit")
    ],
    targets: [
        .target(
            name: "PwgAPIKit",
            dependencies: [
                "PwgKit"
            ],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PwgAPIKitTests",
            dependencies: [
                "PwgKit"
            ],
            path: "Tests",
            resources: [
                .process("community"),
                .process("reflection"),
                .process("pwg")
            ]
        )
    ],
//    swiftLanguageModes: [.v5],
)
