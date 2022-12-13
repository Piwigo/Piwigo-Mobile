//
//  ImageSize.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 05/10/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

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
    // Default Piwigo image minimum number of pixels
    public var minPixels: CGFloat {
        // Get device scale factor
        let scale: CGFloat = UIScreen.main.scale
        
        // Default width
        var width: CGFloat = 120
        switch(self) {
        case .square:
            width = 120
        case .thumb:
            width = 144
        case .xxSmall:
            width = 240
        case .xSmall:
            width = 324
        case .small:
            width = 432
        case .medium:
            width = 594
        case .large:
            width = 756
        case .xLarge:
            width = 918
        case .xxLarge:
            width = 1242
        case .fullRes:
            width = 1242
        }
        return width/scale
    }

    // Default Piwigo image maximum number of pixels
    public var maxPixels: CGFloat {
        // Get device scale factor
        let scale: CGFloat = UIScreen.main.scale
        
        // Default width
        var width: CGFloat = 120
        switch(self) {
        case .square:
            width = 120
        case .thumb:
            width = 144
        case .xxSmall:
            width = 240
        case .xSmall:
            width = 432
        case .small:
            width = 576
        case .medium:
            width = 792
        case .large:
            width = 1008
        case .xLarge:
            width = 1224
        case .xxLarge:
            width = 1656
        case .fullRes:
            width = 1656
        }
        return width/scale
    }

    // Default number of pixels at the current scale
    public var sizeAndScale: String {
        // Get device scale factor
        let scale = Float(UIScreen.main.scale)
        
        // Build size string
        if self == .fullRes {
            return ""
        }
        
        let minPix = lroundf(Float(self.minPixels))
        let maxPix = lroundf(Float(self.maxPixels))
        return String(format: " (%ldx%ld@%.0fx)", maxPix, minPix, scale)
    }

    // Localized name
    public var name: String {
        switch self {
        case .square:
            return NSLocalizedString("thumbnailSizeSquare", comment: "Square")
        case .thumb:
            return NSLocalizedString("thumbnailSizeThumbnail", comment: "Thumbnail")
        case .xxSmall:
            return NSLocalizedString("thumbnailSizeXXSmall", comment: "Tiny")
        case .xSmall:
            return NSLocalizedString("thumbnailSizeXSmall", comment: "Extra Small")
        case .small:
            return NSLocalizedString("thumbnailSizeSmall", comment: "Small")
        case .medium:
            return NSLocalizedString("thumbnailSizeMedium", comment: "Medium")
        case .large:
            return NSLocalizedString("thumbnailSizeLarge", comment: "Large")
        case .xLarge:
            return NSLocalizedString("thumbnailSizeXLarge", comment: "Extra Large")
        case .xxLarge:
            return NSLocalizedString("thumbnailSizeXXLarge", comment: "Huge")
        case .fullRes:
            return NSLocalizedString("thumbnailSizexFullRes", comment: "Full Resolution")
        }
    }
    
    // Argument for Piwigo methods
    public var argument: String {
        switch self {
        case .square:
            return "square"
        case .xxSmall:
            return "2small"
        case .xSmall:
            return "xsmall"
        case .small:
            return "small"
        case .medium, .fullRes:
            return "medium"
        case .large:
            return "large"
        case .xLarge:
            return "xlarge"
        case .xxLarge:
            return "xxlarge"
        case .thumb:
            return "thumb"
        }
    }

    // Path name in which images of the given size are stored
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
