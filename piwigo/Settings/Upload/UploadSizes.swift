//
//  UploadSizes.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import uploadKit

extension pwgPhotoMaxSizes {
    public var name: String {
        switch self {
        case .fullResolution:   return NSLocalizedString("UploadPhotoSize_original", comment: "No Downsizing")
        case .Retina5K:         return "5K | 14.7 Mpx"
        case .UHD4K:            return "4K | 8.29 Mpx"
        case .DCI2K:            return "2K | 2.21 Mpx"
        case .FullHD:           return "Full HD | 2.07 Mpx"
        case .HD:               return "HD | 0.92 Mpx"
        case .qHD:              return "qHD | 0.52 Mpx"
        case .nHD:              return "nHD | 0.23 Mpx"
        }
    }
}

extension pwgVideoMaxSizes {
    public var name: String {
        switch self {
        case .fullResolution:   return NSLocalizedString("UploadPhotoSize_original", comment: "No Downsizing")
        case .UHD4K:            return "4K | ≈26.7 Mbit/s"
        case .FullHD:           return "Full HD | ≈15.6 Mbit/s"
        case .HD:               return "HD | ≈11.3 Mbit/s"
        case .qHD:              return "qHD | ≈5.8 Mbit/s"
        case .nHD:              return "nHD | ≈2.8 Mbit/s"
        }
    }
}
