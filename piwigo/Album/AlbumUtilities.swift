//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

@objc
class AlbumUtilities: NSObject {
    
    // MARK: - Album Collections
    @objc
    class func footerLegend(for nberOfImages: Int) -> String {
        var legend = ""
        if nberOfImages == NSNotFound {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if nberOfImages == 0 {
            // Not loading and no images
            legend = NSLocalizedString("noImages", comment:"No Images")
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: nberOfImages)) {
                let format:String = nberOfImages > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
}
