// swift-tools-version: 6.0
//
//  Package.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PwgUIKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgUIKit",
            targets: ["PwgUIKit"]
        ),
    ],
    dependencies: [
        .package(path: "../PwgKit")
    ],
    targets: [
        .target(
            name: "PwgUIKit",
            dependencies: [
                "PwgKit"
            ],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6],
)
