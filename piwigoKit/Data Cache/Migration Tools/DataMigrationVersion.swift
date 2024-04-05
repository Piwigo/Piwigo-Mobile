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
    // When adding a version, do not forget to also add it to
    // the func compatibleVersionForStoreMetadata(metadata) in DataMigrator
    case version01 = "DataModel 01"                 // from v2.4.8  on 25 March 2020
    case version02 = "DataModel 02 (+Location)"     // from v2.5    on 27 August 2020 (added on 1 May 2020)
    case version03 = "DataModel 03 (+Upload)"       // from v2.5    on 27 August 2020
    case version04 = "DataModel 04 (Upload)"        // from v2.5.2  on 3 December 2020
    case version05 = "DataModel 05 (Upload)"        // from v2.6    on 3 March 2021
    case version06 = "DataModel 06 (Upload)"        // from v2.6    on 3 March 2021
    case version07 = "DataModel 07 (Upload)"        // from v2.6.2  on 3 May 2021
    case version08 = "DataModel 08 (Upload)"        // from v2.7    on 12 August 2021 (moved to PiwigoKit)
    case version09 = "DataModel 09 (Upload)"        // from v2.12   on 3 July 2022
    case version0A = "DataModel 0A (+Server)"       // from v3.00   added to beta on 21 August 2022
    case version0B = "DataModel 0B (Image)"         // from v3.00   added to beta on 28 February 2023
    case version0C = "DataModel 0C (Sizes)"         // from v3.00   added to beta on 17 May 2023
    case version0D = "DataModel 0D (Album)"         // from v3.2    added to beta on 18 March 2024

    static var current: DataMigrationVersion {
        guard let current = allCases.last else {
            fatalError("••> No model versions found!")
        }
        return current
    }

    func nextVersion() -> DataMigrationVersion? {
        switch self {
        case .version01:
            return .version02
        case .version02:
            return .version03
        case .version03:
            return .version04
        case .version04:
            return .version05
        case .version05:
            return .version06
        case .version06:
            return .version07
        case .version07:
            return .version08
        case .version08:
            return .version09
        case .version09:
            return .version0C
        case .version0A:
            return .version0B
        case .version0B:
            return .version0C
        case .version0C:
            return .version0D
        case .version0D:
            return nil
        }
    }
}
