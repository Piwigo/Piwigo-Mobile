// swift-tools-version: 6.0
//
//  Package.swift
//  PwgMetadataKit
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Metadata of the photos: readers of the metadata of an image file, formatters,
//  summary and model of the table presenting them, shared by the app and its extensions.
//

import PackageDescription

let package = Package(
    name: "PwgMetadataKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgMetadataKit",
            targets: ["PwgMetadataKit"]
        ),
    ],
    targets: [
        .target(
            name: "PwgMetadataKit",
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PwgMetadataKitTests",
            dependencies: ["PwgMetadataKit"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6],
)
