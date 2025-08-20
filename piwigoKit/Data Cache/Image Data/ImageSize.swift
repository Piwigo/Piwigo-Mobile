//
//  ImageSize.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 05/10/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

public enum pwgImageSize : Int16, CaseIterable, Sendable {
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
    // Maximum zoom scale of album thumbnails after applying saliency
    public static let maxSaliencyScale: CGFloat = 2
    
    // Maximum zoom scale of fullscreen image previews
    public static let maxZoomScale: CGFloat = 4
    
    // Default Piwigo image minimum number of points
    public func minPoints(forScale scale: CGFloat)-> CGFloat {
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
    
    // Default Piwigo image maximum number of points
    public func maxPoints(forScale scale: CGFloat) -> CGFloat {
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
    public func sizeAndScale(forScale scale: CGFloat) -> String {
        // Build size string
        if self == .fullRes {
            return ""
        }
        
        let minPnts = lroundf(Float(self.minPoints(forScale: scale)))
        let maxPnts = lroundf(Float(self.maxPoints(forScale: scale)))
        return String(format: " (%ldx%ld@%.0fx)", maxPnts, minPnts, scale)
    }
    
    // Localized name
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var name: String {
        switch self {
        case .square:
            return String(localized: "thumbnailSizeSquare", bundle: piwigoKit,
                          comment: "Square")
        case .thumb:
            return String(localized: "thumbnailSizeThumbnail", bundle: piwigoKit,
                          comment: "Thumbnail")
        case .xxSmall:
            return String(localized: "thumbnailSizeXXSmall", bundle: piwigoKit,
                          comment: "Tiny")
        case .xSmall:
            return String(localized: "thumbnailSizeXSmall", bundle: piwigoKit,
                          comment: "Extra Small")
        case .small:
            return String(localized: "thumbnailSizeSmall", bundle: piwigoKit,
                          comment: "Small")
        case .medium:
            return String(localized: "thumbnailSizeMedium", bundle: piwigoKit,
                          comment: "Medium")
        case .large:
            return String(localized: "thumbnailSizeLarge", bundle: piwigoKit,
                          comment: "Large")
        case .xLarge:
            return String(localized: "thumbnailSizeXLarge", bundle: piwigoKit,
                          comment: "Extra Large")
        case .xxLarge:
            return String(localized: "thumbnailSizeXXLarge", bundle: piwigoKit,
                          comment: "Huge")
        case .fullRes:
            return String(localized: "thumbnailSizexFullRes", bundle: piwigoKit,
                          comment: "Full Resolution")
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
    
    static public func <=(left: pwgImageSize, right: pwgImageSize) -> Bool {
        return left.rawValue <= right.rawValue
    }
    
    static public func >=(left: pwgImageSize, right: pwgImageSize) -> Bool {
        return left.rawValue >= right.rawValue
    }
}
