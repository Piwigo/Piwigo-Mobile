// swift-tools-version: 5.9
//
//  Package.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "PwgKit",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PwgKit",
            targets: ["PwgKit"]
        )
    ],
    targets: [
        .target(
            name: "PwgKit",
            path: "Sources",
            resources: [
//                .process("Resources/"),
                .process("Cache/DataModel.xcdatamodeld"),
                .process("Cache/MigrationTools/MappingModel_0A_to_0B/MappingModel_0A_to_0B.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0B_to_0C/MappingModel_0B_to_0C.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_09_to_0C/MappingModel_09_to_0C.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0F_to_0G/MappingModel_0F_to_0G.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0G_to_0H/MappingModel_0G_to_0H.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0F_to_0H/MappingModel_0F_to_0H.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0H_to_0I/MappingModel_0H_to_0I.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0I_to_0J/MappingModel_0I_to_0J.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0H_to_0J/MappingModel_0H_to_0J.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0J_to_0K/MappingModel_0J_to_0K.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0K_to_0L/MappingModel_0K_to_0L.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0J_to_0L/MappingModel_0J_to_0L.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0L_to_0M/Mapping_Model_0L_to_0M.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0M_to_0N/Mapping_Model_0M_to_0N.xcmappingmodel"),
                .process("Cache/MigrationTools/MappingModel_0L_to_0N/Mapping_Model_0L_to_0N.xcmappingmodel")
            ]
        ),
    ]
)
