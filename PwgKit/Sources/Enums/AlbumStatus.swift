//
//  AlbumStatus.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 17/08/2026.
//

import Foundation

public enum pwgAlbumStatus: Int16, Sendable {
    case unknown = -1
    case publicStatus
    case privateStatus
}

extension pwgAlbumStatus: CaseIterable {
    // Argument for Piwigo methods
    public var argument: String {
        switch self {
        case .publicStatus:
            return "public"
        case .privateStatus:
            return "private"
        default:
            return "unknown"
        }
    }
}
