//
//  UIImage+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

extension UIImage {
    
    func resize(to dimension: CGFloat, opaque: Bool, scale: CGFloat = UIScreen.main.scale,
                contentMode: UIView.ContentMode = .scaleAspectFit) -> UIImage {
        var width: CGFloat
        var height: CGFloat
        var newImage: UIImage

        let size = self.size
        let aspectRatio =  size.width/size.height

        switch contentMode {
        case .scaleAspectFit:
            if aspectRatio > 1 {                            // Landscape image
                width = dimension
                height = dimension / aspectRatio
            } else {                                        // Portrait image
                height = dimension
                width = dimension * aspectRatio
            }
        case .scaleAspectFill:
            if aspectRatio > 1 {                            // Landscape image
                width = dimension * aspectRatio
                height = dimension
            } else {                                        // Portrait image
                width = dimension
                height = dimension / aspectRatio
            }
        default:
            fatalError("UIIMage.resizeToFit(): FATAL: Unimplemented ContentMode")
        }

        if #available(iOS 10.0, *) {
            let renderFormat = UIGraphicsImageRendererFormat.default()
            renderFormat.opaque = opaque
            renderFormat.scale = scale
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: renderFormat)
            newImage = renderer.image { (context) in
                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        } else {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), opaque, 0)
                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }

        return newImage
    }
    
    func fixOrientation() -> UIImage {
        // No-op if the orientation is already correct
        if self.imageOrientation == .up {
            return self
        }

        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity

        switch self.imageOrientation {
            case .down, .downMirrored:
                transform = transform.translatedBy(x: self.size.width, y: self.size.height)
                transform = transform.rotated(by: .pi)
            case .left, .leftMirrored:
                transform = transform.translatedBy(x: self.size.width, y: 0)
                transform = transform.rotated(by: .pi / 2)
            case .right, .rightMirrored:
                transform = transform.translatedBy(x: 0, y: self.size.height)
                transform = transform.rotated(by: -.pi / 2)
            case .up, .upMirrored:
                break
            @unknown default:
                break
        }

        switch self.imageOrientation {
            case .upMirrored, .downMirrored:
                transform = transform.translatedBy(x: self.size.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .leftMirrored, .rightMirrored:
                transform = transform.translatedBy(x: self.size.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .up, .down, .left, .right:
                break
            @unknown default:
                break
        }

        // Now we draw the underlying CGImage into a new context,
        // applying the transform calculated above.
        let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height),
                            bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0,
                            space: self.cgImage!.colorSpace!, bitmapInfo: self.cgImage!.bitmapInfo.rawValue)
        ctx?.concatenate(transform)
        switch self.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                // Grr...
                ctx?.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: self.size.height , height: self.size.width ))
            default:
                ctx?.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: self.size.width , height: self.size.height ))
        }

        // And now we just create a new UIImage from the drawing context
        let cgimg = ctx?.makeImage()
        var img: UIImage? = nil
        if let cgimg = cgimg {
            img = UIImage(cgImage: cgimg)
        }
        return img!
    }
    
    func crop(width: CGFloat, height: CGFloat) -> UIImage?
    {
        // Call crop(1.0,1.0) for obtaining a square image
        let imageScale = min(self.size.width / width,
                             self.size.height / height)

        // Handle images larger than shown-on-screen size
        let cropZone = CGRect(x:self.size.width/2.0 - (width / 2.0) * imageScale,
                              y:self.size.height/2.0 - (height / 2.0) * imageScale,
                              width: width * imageScale,
                              height: height * imageScale)

        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = self.cgImage?.cropping(to:cropZone) else {
            // Return original image if failed
            return self
        }

        // Return image to UIImage
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)
        return croppedImage
    }
}
