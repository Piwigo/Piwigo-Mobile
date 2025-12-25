//
//  JSONManager+Image.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation
import UIKit

public extension JSONManager {
    
    @concurrent
    func rotate(_ image: Image, by angle: Double) async throws(PwgKitError) {
        // Prepare parameters for rotating image
        let paramsDict: [String : Any] = ["image_id"  : image.pwgID,
                                          "angle"     : angle * 180.0 / .pi,
                                          "pwg_token" : NetworkVars.shared.pwgToken,
                                          "rotate_hd" : true]
        
        _ = try await postRequest(withMethod: pwgImageRotate, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ImageRotateJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
        
        // Image rotated successfully ► Rotate thumbnails in cache
        /// Image data not always immediately available from server.
        /// We rotate the images stored in cache instead of downloading them.
        image.rotateThumbnails(by: angle)
    }
}


extension Image {
    // Rotates all thumbnails
    fileprivate func rotateThumbnails(by angle: CGFloat) {
        // Initialisation
        guard let serverID = self.server?.uuid else { return }
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        let fm = FileManager.default
        
        // Loop over all sizes
        autoreleasepool {
            pwgImageSize.allCases.forEach { size in
                // Determine URL of image in cache
                let fileURL = cacheDir.appendingPathComponent(size.path)
                    .appendingPathComponent(String(self.pwgID))
                
                // Rotate thumbnail if any
                if let image = UIImage(contentsOfFile: fileURL.path),
                   let rotatedImage = image.rotated(by: -angle),
                   let data = rotatedImage.jpegData(compressionQuality: 1.0) as? NSData
                {
                    let filePath = fileURL.path
                    try? fm.removeItem(atPath: filePath)
                    do {
                        try data.write(toFile: filePath, options: .atomic)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                
                // Swap dimensions
                switch size {
                case .square:
                    self.sizes.square?.dimensionsSwaped()
                case .thumb:
                    self.sizes.thumb?.dimensionsSwaped()
                case .xxSmall:
                    self.sizes.xxsmall?.dimensionsSwaped()
                case .xSmall:
                    self.sizes.xsmall?.dimensionsSwaped()
                case .small:
                    self.sizes.small?.dimensionsSwaped()
                case .medium:
                    self.sizes.medium?.dimensionsSwaped()
                case .large:
                    self.sizes.large?.dimensionsSwaped()
                case .xLarge:
                    self.sizes.xlarge?.dimensionsSwaped()
                case .xxLarge:
                    self.sizes.xxlarge?.dimensionsSwaped()
                case .xxxLarge:
                    self.sizes.xxxlarge?.dimensionsSwaped()
                case .xxxxLarge:
                    self.sizes.xxxxlarge?.dimensionsSwaped()
                case .fullRes:
                    self.fullRes?.dimensionsSwaped()
                }
                
                // Rotate optimised image if any
                let filePath = fileURL.path + CacheVars.shared.optImage
                if let image = UIImage(contentsOfFile: filePath),
                   let rotatedImage = image.rotated(by: -angle) {
                    rotatedImage.saveInOptimumFormat(atPath: filePath)
                }
                
                // The file size and MD5 checksum are unchanged.
            }
        }
    }
}


extension UIImage {
    // Save downsampled images in HEIC or JPEG format
    public func saveInOptimumFormat(atPath filePath: String) {
        autoreleasepool {
            let fm = FileManager.default
            try? fm.removeItem(atPath: filePath)
            if #available(iOS 17, *) {
                if let data = self.heicData() as? NSData {
                    do {
                        try data.write(toFile: filePath, options: .atomic)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            } else if let data = self.jpegData(compressionQuality: 1.0) as? NSData {
                do {
                    try data.write(toFile: filePath, options: .atomic)
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        }
    }
}
