//
//  Package.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

// swift-tools-version:6.0
import Foundation
import PackageDescription

let package = Package(
    name: "PwgUploadKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PwgUploadKit",
            targets: ["PwgUploadKit"]
        )
    ],
    targets: [
        .target(
            name: "PwgUploadKit",
            path: "Sources",
            exclude: ["Resources/Localizable.xcstrings"],   // Exclude from automatic inclusion
            sources: [
                ".",
                "UploadManager",
                "UploadSessions",
                "SupportingFiles"
            ],
            resources: [
                .process("Resources/")
            ]
        ),
    ]
)
