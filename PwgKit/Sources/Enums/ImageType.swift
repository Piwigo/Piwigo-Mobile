//
//  ImageType.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 17/05/2026.
//

import UIKit

public enum pwgImageType: Sendable {
    case album, image, help
}

extension pwgImageType {
    public var placeHolder: UIImage {
        switch self {
        case .album:
            return UIImage(named: "unknownAlbum")!
        case .image:
            return UIImage(named: "unknownImage")!
        case .help:
            return UIImage(systemName: "questionmark")!
        }
    }
}
