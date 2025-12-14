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
    case version01 = "DataModel 01"                         // from v2.4.8  on 25 March 2020
    case version02 = "DataModel 02 (+Location)"             // from v2.5    on 27 August 2020 (added on 1 May 2020)
    case version03 = "DataModel 03 (+Upload)"               // from v2.5    on 27 August 2020
    case version04 = "DataModel 04 (Upload)"                // from v2.5.2  on 3 December 2020
    case version05 = "DataModel 05 (Upload)"                // from v2.6    on 3 March 2021
    case version06 = "DataModel 06 (Upload)"                // from v2.6    on 3 March 2021
    case version07 = "DataModel 07 (Upload)"                // from v2.6.2  on 3 May 2021
    case version08 = "DataModel 08 (Upload)"                // from v2.7    on 12 August 2021 (moved to PiwigoKit)
    case version09 = "DataModel 09 (Upload)"                // from v2.12   on 3 July 2022
    case version0A = "DataModel 0A (+Server)"               // from v3.0    on 21 August 2022
    case version0B = "DataModel 0B (Image)"                 // from v3.0    on 28 February 2023
    case version0C = "DataModel 0C (Sizes)"                 // from v3.0    on 17 May 2023
    case version0D = "DataModel 0D (Album)"                 // from v3.2    on 18 March 2024
    case version0E = "DataModel 0E (Image)"                 // from v3.2    on 28 May 2024
    case version0F = "DataModel 0F (None)"                  // from v3.2    on 12 June 2024
    case version0G = "DataModel 0G (NSAttributedString)"    // from v3.3    on 2 March 2025
    case version0H = "DataModel 0H (User.downloadRights)"   // from v3.3    on 8 March 2025
    case version0I = "DataModel 0I (Upload.renameFile)"     // from v3.4    on 1 June 2025
    case version0J = "DataModel 0J (Group)"                 // from v3.4    on 14 June 2025
    case version0K = "DataModel 0K (Image.fileType)"        // from v3.5    on 19 July 2025
    case version0L = "DataModel 0L (.comment)"              // from v3.5    on 8 August 2025
    case version0M = "DataModel 0M (.comment)"              // from v4.1.3  on 14 December 2025

    static var current: DataMigrationVersion {
        guard let current = allCases.last else {
            preconditionFailure("••> No model versions found!")
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
            return .version0F
        case .version0D:
            return .version0F
        case .version0E:
            return .version0F
        case .version0F:
            return .version0H
        case .version0G:
            return .version0H
        case .version0H:
            return .version0J
        case .version0I:
            return .version0J
        case .version0J:
            return .version0L
        case .version0K:
            return .version0L
        case .version0L:
            return .version0M
        default:
            return nil
        }
    }
}
