//
//  AVURLAsset+AppTools.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 14/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import AVFoundation
import UIKit

extension AVURLAsset {
    /// Returns the first frame of the video, or nil if it could not be extracted.
    public func extractedImage() -> UIImage? {
        let generator = AVAssetImageGenerator(asset: self)
        generator.appliesPreferredTrackTransform = true         // respect rotation/orientation
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        // Time zero = first frame
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        do {
            return UIImage(cgImage: try generator.copyCGImage(at: time, actualTime: nil))
        }
        catch {
            // Could not extract frame
            return nil
        }
    }
}
