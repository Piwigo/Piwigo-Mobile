//
//  UIImage+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/11/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Vision
import UIKit

extension UIImage {
    
    // MARK: - Saliency Analysis
//    func processSaliency() -> UIImage? {
//        // Disabled when using simulator
//        #if targetEnvironment(simulator)
//        return nil
//        #else
//        // Check that it is possible to perform a saliency request
//        // by checking the pixel format of the image.
//        autoreleasepool {
//            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
//            var imageData: Data?
//            if #available(iOS 17, *) {
//                imageData = self.heicData()
//            } else {
//                imageData = self.pngData()
//            }
//            guard let imageData = imageData,
//                  let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions),
//                  let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, imageSourceOptions),
//                  ImageUtilities.supportsPixelFormat(ofCGImage: imageRef),
//                  let cgImage = self.cgImage
//            else {
//                return nil
//            }
//            
//            // Create request handler
//            //        let start:Double = CFAbsoluteTimeGetCurrent()
//            let cgOrientation = CGImagePropertyOrientation.init(self.imageOrientation)
//            let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
//            
//            // Create attention based saliency request
//            let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
//            attentionRequest.revision = VNGenerateAttentionBasedSaliencyImageRequestRevision1
//            
//            // Create objectness based saliency request
//            let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
//            objectnessRequest.revision = VNGenerateObjectnessBasedSaliencyImageRequestRevision1
//            
//            // Search for regions of interest
//            do {
//                try requestHandler.perform([attentionRequest, objectnessRequest])
//            } catch let error {
//                debugPrint("Failed to perform image request: \(error.localizedDescription)")
//                return nil
//            }
//            
//            // Attention-based saliency requests return only one bounding box
//            var attentionConfidence:Float = 0.0
//            let attentionResult = attentionRequest.results?.first
//            let attentionObservation = attentionResult as VNSaliencyImageObservation?
//            let attentionObject = attentionObservation?.salientObjects?.first
//            attentionConfidence = attentionObject?.confidence ?? 0.0
//            
//            // Object-based saliency requests return up to three bounding boxes
//            var objectnessConfidence:Float = 0.0
//            let objectnessResult = objectnessRequest.results?.first
//            let objectnessObservation = objectnessResult as VNSaliencyImageObservation?
//            let objectnessObject = objectnessObservation?.salientObjects?
//                .sorted(by: { $0.confidence > $1.confidence }).first
//            objectnessConfidence = objectnessObject?.confidence ?? 0.0
//            
//            // Priority to attention-based saliency
//            if attentionConfidence > 0.8,
//               attentionConfidence > objectnessConfidence,
//               let salientObject = attentionObject,
//               salientObject.boundingBox.width > 0.5,
//               salientObject.boundingBox.height > 0.5 {
//                let salientRect = VNImageRectForNormalizedRect(salientObject.boundingBox,
//                                                               cgImage.width, cgImage.height)
//                // Crop image
//                guard let croppedImage = cgImage.cropping(to: salientRect) else { return nil }
//                //            let diff:Double = (CFAbsoluteTimeGetCurrent() - start)*1000.0
//                //            debugPrint("   processed attention based saliency in \(round(diff*10.0)/10.0) ms")
//                return UIImage(cgImage:croppedImage)
//            }
//            
//            // Objectness-based saliency
//            if objectnessConfidence > 0.8,
//               let salientObject = objectnessObject,
//               salientObject.boundingBox.width > 0.5,
//               salientObject.boundingBox.height > 0.5 {
//                let salientRect = VNImageRectForNormalizedRect(salientObject.boundingBox,
//                                                               cgImage.width, cgImage.height)
//                // Crop image
//                guard let croppedImage = cgImage.cropping(to: salientRect) else { return nil }
//                //            let diff:Double = (CFAbsoluteTimeGetCurrent() - start)*1000.0
//                //            debugPrint("   processed objectness based saliency in \(round(diff*10.0)/10.0) ms")
//                return UIImage(cgImage:croppedImage)
//            }
//            return nil
//        }
//        #endif
//    }
}

//extension UIImage.Orientation {
//    init(_ cgOrientation: CGImagePropertyOrientation) {
//        switch cgOrientation {
//            case .up: self = .up
//            case .upMirrored: self = .upMirrored
//            case .down: self = .down
//            case .downMirrored: self = .downMirrored
//            case .left: self = .left
//            case .leftMirrored: self = .leftMirrored
//            case .right: self = .right
//            case .rightMirrored: self = .rightMirrored
//        }
//    }
//}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
            assertionFailure("Unknown CGImageOrientation")
        }
    }
}
