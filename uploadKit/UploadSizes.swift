//
//  UploadSizes.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import piwigoKit

// MARK: - Max Photo Sizes
public enum pwgPhotoMaxSizes: Int16, CaseIterable {
    case fullResolution = 0, Retina5K, UHD4K, DCI2K, FullHD, HD, qHD, nHD
}

extension pwgPhotoMaxSizes {
    public var pixels: Int {
        switch self {
        case .fullResolution:   return Int.max
        case .Retina5K:         return 5120
        case .UHD4K:            return 3840
        case .DCI2K:            return 2048
        case .FullHD:           return 1920
        case .HD:               return 1280
        case .qHD:              return 960
        case .nHD:              return 640
        }
    }
}

// MARK: - Max Video Sizes
public enum pwgVideoMaxSizes: Int16, CaseIterable {
    case fullResolution = 0, UHD4K, FullHD, HD, qHD, nHD
}

extension pwgVideoMaxSizes {
    public var pixels: Int {
        switch self {
        case .fullResolution:   return Int.max
        case .UHD4K:            return 3840
        case .FullHD:           return 1920
        case .HD:               return 1280
        case .qHD:              return 960
        case .nHD:              return 640
        }
    }
}
