// swift-tools-version:6.0
//
//  Package.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PwgUploadKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgUploadKit",
            targets: ["PwgUploadKit"]
        )
    ],
    dependencies: [
        .package(path: "../PwgKit"),
        .package(path: "../PwgAPIKit"),
        .package(path: "../PwgCacheKit")
    ],
    targets: [
        .target(
            name: "PwgUploadKit",
            dependencies: [
                "PwgKit",
                "PwgAPIKit",
                "PwgCacheKit"
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
        ),
    ]
)
