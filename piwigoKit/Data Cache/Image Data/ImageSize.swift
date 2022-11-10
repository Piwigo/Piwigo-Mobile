//
//  ImageSize.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 05/10/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum pwgImageSize : Int16, CaseIterable {
    case square = 0
    case thumb
    case xxSmall
    case xSmall
    case small
    case medium
    case large
    case xLarge
    case xxLarge
    case fullRes
}

extension pwgImageSize {
    public var path: String {
        switch self {
        case .square:
            return "Square"
        case .thumb:
            return "Thumbnail"
        case .xxSmall:
            return "XXSmall"
        case .xSmall:
            return "XSmall"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .xLarge:
            return "XLarge"
        case .xxLarge:
            return "XXLarge"
        case .fullRes:
            return "FullRes"
        }
    }
}
