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
    @available(iOS 13.0, *)
    func processSaliency() -> UIImage? {
        // Disabled when using simulator
        #if targetEnvironment(simulator)
        return nil
        #else
        // Retrieve CGImage version
        guard let cgImage = self.cgImage else { return nil }
        
        // Create request handler
//        let start:Double = CFAbsoluteTimeGetCurrent()
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create attention based saliency request
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        attentionRequest.revision = VNGenerateAttentionBasedSaliencyImageRequestRevision1

        // Create objectness based saliency request
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        objectnessRequest.revision = VNGenerateObjectnessBasedSaliencyImageRequestRevision1

        // Search for regions of interest
        try? requestHandler.perform([attentionRequest, objectnessRequest])

        // Attention-based saliency requests return only one bounding box
        var attentionConfidence:Float = 0.0
        let attentionResult = attentionRequest.results?.first
        let attentionObservation = attentionResult as VNSaliencyImageObservation?
        let attentionObject = attentionObservation?.salientObjects?.first
        attentionConfidence = attentionObject?.confidence ?? 0.0
        
        // Object-based saliency requests return up to three bounding boxes
        var objectnessConfidence:Float = 0.0
        let objectnessResult = objectnessRequest.results?.first
        let objectnessObservation = objectnessResult as VNSaliencyImageObservation?
        let objectnessObject = objectnessObservation?.salientObjects?
            .sorted(by: { $0.confidence > $1.confidence }).first
        objectnessConfidence = objectnessObject?.confidence ?? 0.0
        
        // Priority to attention-based saliency
        if attentionConfidence > 0.7,
           attentionConfidence > objectnessConfidence,
           let salientObject = attentionObject,
           salientObject.boundingBox.width > 0.3,
           salientObject.boundingBox.height > 0.3 {
            let salientRect = VNImageRectForNormalizedRect(salientObject.boundingBox,
                                                           cgImage.width, cgImage.height)
            // Crop image
            guard let croppedImage = cgImage.cropping(to: salientRect) else { return nil }
//            let diff:Double = (CFAbsoluteTimeGetCurrent() - start)*1000.0
//            print("   processed attention based saliency in \(round(diff*10.0)/10.0) ms")
            return UIImage(cgImage:croppedImage)
        }

        // Objectness-based saliency
        if objectnessConfidence > 0.7,
            let salientObject = objectnessObject,
            salientObject.boundingBox.width > 0.3,
            salientObject.boundingBox.height > 0.3 {
             let salientRect = VNImageRectForNormalizedRect(salientObject.boundingBox,
                                                            cgImage.width, cgImage.height)
             // Crop image
             guard let croppedImage = cgImage.cropping(to: salientRect) else { return nil }
//            let diff:Double = (CFAbsoluteTimeGetCurrent() - start)*1000.0
//            print("   processed objectness based saliency in \(round(diff*10.0)/10.0) ms")
             return UIImage(cgImage:croppedImage)
        }
        return nil
        #endif
    }

    // MARK: - Image Manipulation
    func rotated(by angle:CGFloat) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: angle)).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: angle)
        // Draw the image at its center
        let xPos: CGFloat = -self.size.width/2.0
        let yPos: CGFloat = -self.size.height/2.0
        self.draw(in: CGRect(x: xPos, y: yPos, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
