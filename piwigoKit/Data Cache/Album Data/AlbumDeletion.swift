//
//  AlbumDeletion.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum pwgAlbumDeletionMode {
    case none, orphaned, all
}

extension pwgAlbumDeletionMode {
    public var pwgArg: String {
        switch self {
        case .none:
            return "no_delete"
        case .orphaned:
            return "delete_orphans"
        case .all:
            return "force_delete"
        }
    }
}
