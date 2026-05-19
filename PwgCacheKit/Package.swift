// swift-tools-version: 5.9
//
//  Package.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PwgCacheKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgCacheKit",
            targets: ["PwgCacheKit"]
        )
    ],
    dependencies: [
        .package(path: "../PwgKit"),
    ],
    targets: [
        .target(
            name: "PwgCacheKit",
            dependencies: [
                "PwgKit"
            ],
            path: "Sources",
            resources: [
//                .process("Resources/"),
                .process("DataModel.xcdatamodeld"),
                .process("MigrationTools/MappingModel_0A_to_0B/MappingModel_0A_to_0B.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0B_to_0C/MappingModel_0B_to_0C.xcmappingmodel"),
                .process("MigrationTools/MappingModel_09_to_0C/MappingModel_09_to_0C.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0F_to_0G/MappingModel_0F_to_0G.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0G_to_0H/MappingModel_0G_to_0H.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0F_to_0H/MappingModel_0F_to_0H.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0H_to_0I/MappingModel_0H_to_0I.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0I_to_0J/MappingModel_0I_to_0J.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0H_to_0J/MappingModel_0H_to_0J.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0J_to_0K/MappingModel_0J_to_0K.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0K_to_0L/MappingModel_0K_to_0L.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0J_to_0L/MappingModel_0J_to_0L.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0L_to_0M/Mapping_Model_0L_to_0M.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0M_to_0N/Mapping_Model_0M_to_0N.xcmappingmodel"),
                .process("MigrationTools/MappingModel_0L_to_0N/Mapping_Model_0L_to_0N.xcmappingmodel")
            ]
        ),
    ],
//    swiftLanguageModes: [.v5],
)
