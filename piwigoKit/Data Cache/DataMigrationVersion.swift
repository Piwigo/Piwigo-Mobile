//
//  DataMigrationVersion.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

// MARK: - Core Data Migration Version
/// See: https://williamboles.com/progressive-core-data-migration/
enum DataMigrationVersion: String, CaseIterable {
    case version1 = "DataModel"
    case version2 = "DataModel 2 (+Location)"
    case version3 = "DataModel 3 (+Upload)"
    case version4 = "DataModel 4 (Upload)"

    static var current: DataMigrationVersion {
        guard let current = allCases.last else {
            fatalError("••> No model versions found!")
        }
        return current
    }

    func nextVersion() -> DataMigrationVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return .version3
        case .version3:
            return .version4
        case .version4:
            return nil
        }
    }
}
